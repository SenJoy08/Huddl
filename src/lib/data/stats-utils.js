/**
 * Calculate attendance from completed event memberships that have a recorded
 * attendance decision. Unreviewed memberships are excluded until the host
 * records attendance, matching the public player-stats calculation.
 * @param {{showed_up?: boolean | null}[]} memberships
 * @returns {number | null}
 */
export function calculateAttendancePercent(memberships) {
  const knownAttendance = (memberships ?? []).filter(
    (membership) => membership.showed_up === true || membership.showed_up === false
  );

  if (!knownAttendance.length) return null;

  const attended = knownAttendance.filter((membership) => membership.showed_up === true).length;
  return Math.round((attended / knownAttendance.length) * 100);
}
