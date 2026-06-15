const resolvedPromise = () => Promise.resolve();

module.exports = {
  selectionAsync: resolvedPromise,
  impactAsync: resolvedPromise,
  notificationAsync: resolvedPromise,
  ImpactFeedbackStyle: {
    Light: 'light',
    Medium: 'medium',
    Heavy: 'heavy',
    Rigid: 'rigid',
    Soft: 'soft',
  },
  NotificationFeedbackType: {
    Success: 'success',
    Warning: 'warning',
    Error: 'error',
  },
};
