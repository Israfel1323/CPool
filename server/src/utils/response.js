/**
 * Success Response
 */
export function successResponse(
  res,
  data = null,
  message = 'Success',
  statusCode = 200
) {
  return res.status(statusCode).json({
    success: true,
    timestamp: new Date().toISOString(),
    message,
    data,
  });
}

/**
 * Error Response
 */
export function errorResponse(
  res,
  message = 'Something went wrong.',
  code = 'UNKNOWN_ERROR',
  statusCode = 500
) {
  return res.status(statusCode).json({
    success: false,
    timestamp: new Date().toISOString(),
    code,
    message,
  });
}