import { query } from '../../db/pool.js';

/**
 * Creates emergency-contact notification records for an SOS alert.
 *
 * No external SMS provider is used yet.
 * Notifications are therefore recorded as "not_configured".
 */
export async function createEmergencyContactNotifications({
    sosAlertId,
    userId,
    userName,
    fromAddress,
    toAddress,
    latitude,
    longitude,
    message,
    shareToken,
}) {
    const contactsResult = await query(
        `SELECT
            id,
            name,
            phone_number
         FROM emergency_contacts
         WHERE user_id = $1
         ORDER BY created_at ASC`,
        [userId],
    );

    if (contactsResult.rows.length === 0) {
        return {
            created: 0,
            notifications: [],
        };
    }

    const location =
        latitude != null && longitude != null
            ? `${latitude}, ${longitude}`
            : 'Location unavailable';

    const trip =
        fromAddress || toAddress
            ? `${fromAddress ?? 'Unknown'} → ${toAddress ?? 'Unknown'}`
            : 'Trip details unavailable';

    const shareLink = shareToken
        ? `/trip-safety/share/${shareToken}`
        : null;

    const baseMessage = [
        `CPool SOS Alert`,
        ``,
        `User: ${userName || 'Unknown user'}`,
        `Trip: ${trip}`,
        `Location: ${location}`,
        shareLink ? `Live trip location: ${shareLink}` : null,
        message ? `Message: ${message}` : null,
        ``,
        `Please contact the user or CPool Operations immediately.`,
    ]
        .filter(Boolean)
        .join('\n');

    const notifications = [];

    for (const contact of contactsResult.rows) {
        const result = await query(
            `INSERT INTO emergency_notifications
                (
                    sos_alert_id,
                    emergency_contact_id,
                    channel,
                    status,
                    recipient,
                    message
                )
             VALUES ($1, $2, 'sms', 'not_configured', $3, $4)
             RETURNING
                id,
                sos_alert_id,
                emergency_contact_id,
                channel,
                status,
                recipient,
                message,
                created_at`,
            [
                sosAlertId,
                contact.id,
                contact.phone_number,
                baseMessage,
            ],
        );

        notifications.push({
            ...result.rows[0],
            contact_name: contact.name,
        });
    }

    return {
        created: notifications.length,
        notifications,
    };
}