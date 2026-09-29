<script>
  import EventCard from '$lib/components/EventCard.svelte';
  import BottomNav from '$lib/components/BottomNav.svelte';
  import Icon from '$lib/components/Icon.svelte';
  import { events, friends, sports, stats, profile } from '$lib/data/mock.js';
  import { getSession, getProfile, setProfile, setSession, clearSession } from '$lib/auth/session.js';
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';

  /** @typedef {{ id: number, sport: string, title: string, date: string, dateValue?: string, time?: string, location: string, host: string, members: number, capacity: number, skill: string, color: string, description: string, visibility?: string, status?: string, pendingRequests?: number, ratingsSubmitted?: boolean }} MockEvent */
  /** @typedef {{ title: string, sport: string, dateValue: string, time: string, location: string, capacity: number, skill: string, visibility: string, description: string }} EventForm */

  let active = 'home';
  /** @type {{ id: string, name: string, email: string } | null} */
  let session = null;
  let checkingAuth = true;

  onMount(() => {
    session = getSession();
    checkingAuth = false;
    if (!session) goto('/login');
    joinedEventIds = new Set(eventList.filter((event) => event.host === session?.name && event.status !== 'completed' && event.status !== 'cancelled').map((event) => event.id));
    const storedProfile = getProfile();
    if (storedProfile) {
      userProfile = { ...userProfile, ...storedProfile, settings: { ...userProfile.settings, ...(storedProfile.settings ?? {}) } };
    }
    dateOptions = buildDateOptions();
  });

  let filter = 'All';
  /** @type {MockEvent[]} */
  let eventList = [...events];
  /** @type {MockEvent | null} */
  let selectedEvent = null;
  let hasSelectedEvent = false;
  let showCreate = false;
  let showEdit = false;
  let showNotifications = false;
  let showRating = false;
  let showChat = false;
  /** @type {MockEvent | null} */
  let chatEvent = null;
  let chatDraft = '';
  /** IDs of games the current user has joined (or hosts). */
  let joinedEventIds = new Set(eventList.filter((event) => event.host === session?.name).map((event) => event.id));
  /** @type {MockEvent | null} */
  let ratingEvent = null;
  let search = '';
  let notice = '';
  /** @type {{ value: string, label: string }[]} */
  let dateOptions = [];
  /** @type {EventForm} */
  let newEvent = emptyEventForm();
  /** @type {EventForm} */
  let editEvent = emptyEventForm();
  let calendarOpen = false;
  let timeWheelOpen = false;
  let calendarMonth = new Date(new Date().getFullYear(), new Date().getMonth(), 1);
  /** @type {HTMLElement | null} */
  let periodWheel = null;
  /** @type {HTMLElement | null} */
  let hourWheel = null;
  /** @type {HTMLElement | null} */
  let minuteWheel = null;

  $: filteredEvents = (filter === 'All' ? eventList : eventList.filter((event) => event.sport === filter)).filter((event) => event.status !== 'cancelled');
  /** @typedef {{ id: number, name: string, handle: string, sports: string, status: string, color: string }} MockFriend */
  /** @typedef {{ name: string, handle: string, bio: string, sports: string[], skills: string[], phone?: string, settings?: { showContact?: boolean, eventNotifications?: boolean, friendNotifications?: boolean, ratingNotifications?: boolean } }} MockProfile */
  /** @typedef {{ id: number, name: string, handle: string, sports: string, color: string }} FriendCandidate */
  /** @type {MockFriend[]} */
  let friendList = [...friends];
  /** @type {FriendCandidate[]} */
  let friendCandidates = [
    { id: 5, name: 'Kabir Nair', handle: '@kabir', sports: 'Football · Tennis', color: 'peach' },
    { id: 6, name: 'Aanya Kapoor', handle: '@aanya', sports: 'Badminton · Basketball', color: 'lavender' },
    { id: 7, name: 'Dev Malhotra', handle: '@dev', sports: 'Football · Basketball', color: 'blue' }
  ];
  /** @type {FriendCandidate[]} */
  let incomingRequests = [
    { id: 8, name: 'Nisha Verma', handle: '@nisha', sports: 'Badminton · Tennis', color: 'mint' },
    { id: 9, name: 'Aditya Rao', handle: '@aditya', sports: 'Football', color: 'peach' }
  ];
  /** @type {FriendCandidate | null} */
  let selectedFriend = null;
  /** @type {MockProfile} */
  let userProfile = { ...profile, phone: '', settings: { showContact: false, eventNotifications: true, friendNotifications: true, ratingNotifications: true } };
  /** @type {'profile' | 'sports' | 'account' | 'notifications' | null} */
  let profileSheet = null;
  /** @type {{ name: string, handle: string, bio: string }} */
  let profileDraft = { name: profile.name, handle: profile.handle, bio: profile.bio };
  /** @type {string[]} */
  let sportsDraft = [];
  /** @type {Record<string, string>} */
  let skillsDraft = {};
  let settingsDraft = { showContact: false, eventNotifications: true, friendNotifications: true, ratingNotifications: true };
  /** @type {{ id: number, title: string, message: string, time: string, unread: boolean }[]} */
  let notifications = [
    { id: 1, title: 'Friend request', message: 'Nisha Verma wants to connect with you.', time: '10m ago', unread: true },
    { id: 2, title: 'Game tomorrow', message: 'Sunday Badminton starts at 10:00 AM.', time: '2h ago', unread: true },
    { id: 3, title: 'Rating reminder', message: 'Rate the players from your last game.', time: 'yesterday', unread: false }
  ];
  /** @typedef {{ stars: number, showedUp: boolean, skillMatch: boolean }} RatingDraft */
  /** @type {Record<string, RatingDraft>} */
  let ratingDrafts = {};
  const skillLevels = ['Beginner', 'Amateur', 'Intermediate', 'Seasoned', 'Professional'];
  let eventSportOpen = false;
  let eventSkillOpen = false;
  let visibilityOpen = false;
  /** @typedef {{ id: number, sender: string, text: string, time: string, mine?: boolean }} ChatMessage */
  /** @type {Record<string, ChatMessage[]>} */
  let chatMessages = Object.fromEntries(eventList.map((event) => [String(event.id), [
    { id: event.id * 10 + 1, sender: event.host, text: `Welcome to ${event.title}!`, time: '10:24 AM' },
    { id: event.id * 10 + 2, sender: 'Meera Shah', text: 'Looking forward to the game.', time: '10:27 AM' }
  ]]));
  $: unreadNotifications = notifications.filter((item) => item.unread).length;
  $: filteredFriends = friendList.filter((friend) => `${friend.name} ${friend.handle} ${friend.sports}`.toLowerCase().includes(search.toLowerCase()));
  $: filteredCandidates = friendCandidates.filter((friend) => `${friend.name} ${friend.handle} ${friend.sports}`.toLowerCase().includes(search.toLowerCase()));

  /** @returns {EventForm} */
  function emptyEventForm() {
    return { title: '', sport: 'Football', dateValue: '', time: '', location: '', capacity: 6, skill: 'Intermediate', visibility: 'Public', description: '' };
  }

  function buildDateOptions() {
    const options = [];
    const base = new Date();
    for (let i = 0; i < 30; i += 1) {
      const date = new Date(base);
      date.setHours(12, 0, 0, 0);
      date.setDate(base.getDate() + i);
      const value = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
      const label = i === 0 ? 'Today' : i === 1 ? 'Tomorrow' : date.toLocaleDateString('en-IN', { weekday: 'short', day: 'numeric', month: 'short' });
      options.push({ value, label });
    }
    return options;
  }

  $: calendarDays = buildCalendarDays(calendarMonth);

  /** @param {Date} month */
  function buildCalendarDays(month) {
    const first = new Date(month.getFullYear(), month.getMonth(), 1);
    const startOffset = first.getDay();
    const daysInMonth = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate();
    const cells = [];
    for (let i = 0; i < startOffset; i += 1) cells.push(null);
    for (let day = 1; day <= daysInMonth; day += 1) {
      const date = new Date(month.getFullYear(), month.getMonth(), day, 12);
      cells.push({ value: toDateValue(date), day, date });
    }
    while (cells.length % 7 !== 0) cells.push(null);
    return cells;
  }

  /** @param {Date} date */
  function toDateValue(date) {
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
  }

  /** @param {EventForm} form */
  function openCalendar(form) {
    calendarOpen = true;
    timeWheelOpen = false;
    const selected = form.dateValue ? new Date(`${form.dateValue}T12:00:00`) : new Date();
    calendarMonth = new Date(selected.getFullYear(), selected.getMonth(), 1);
  }

  /** @param {EventForm} form @param {string} value */
  function chooseDate(form, value) {
    if (form === editEvent) editEvent = { ...form, dateValue: value };
    else newEvent = { ...form, dateValue: value };
    calendarOpen = false;
  }

  /** @param {number} monthDelta */
  function moveCalendar(monthDelta) {
    const next = new Date(calendarMonth.getFullYear(), calendarMonth.getMonth() + monthDelta, 1);
    const today = new Date();
    const minMonth = new Date(today.getFullYear(), today.getMonth(), 1);
    if (next >= minMonth) calendarMonth = next;
  }

  /** @param {string} value */
  function isPastDate(value) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    return new Date(`${value}T12:00:00`) < today;
  }

  /** @param {EventForm} form */
  function openTimeWheel(form) {
    timeWheelOpen = true;
    calendarOpen = false;
    setTimeout(() => {
      const parts = timeParts(form.time);
      scrollWheelTo(periodWheel, parts.period === 'PM' ? 1 : 0);
      scrollWheelTo(hourWheel, parts.hour - 1);
      scrollWheelTo(minuteWheel, Math.round(parts.minute / 5));
    }, 0);
  }

  /** @param {HTMLElement | null} element @param {number} index */
  function scrollWheelTo(element, index) {
    if (!element) return;
    // The top spacer centers the first option. Keep that offset when positioning the wheel.
    element.scrollTo({ top: Math.max(0, index) * 44, behavior: 'auto' });
  }

  /** @param {EventForm} form @param {'period' | 'hour' | 'minute'} part @param {Event} event */
  function handleWheelScroll(form, part, event) {
    const element = /** @type {HTMLElement | null} */ (event.currentTarget);
    if (!element) return;
    // The 88px spacers make each 44px option naturally snap into the centered selection band.
    const index = Math.max(0, Math.min(part === 'period' ? 1 : 11, Math.round(element.scrollTop / 44)));
    if (part === 'period') setTimePart(form, 'period', index === 1 ? 'PM' : 'AM');
    if (part === 'hour') setTimePart(form, 'hour', index + 1);
    if (part === 'minute') setTimePart(form, 'minute', index * 5);
  }

  /** @param {EventForm} form @param {'period' | 'hour' | 'minute'} part @param {string | number} value */
  function setTimePart(form, part, value) {
    const current = form.time || '10:00';
    const [rawHour, rawMinute] = current.split(':').map(Number);
    let hour = rawHour || 10;
    let minute = rawMinute || 0;
    if (part === 'period') {
      const isPm = value === 'PM';
      hour = hour % 12 + (isPm ? 12 : 0);
    } else if (part === 'hour') {
      const isPm = hour >= 12;
      hour = Number(value) % 12 + (isPm ? 12 : 0);
    } else {
      minute = Number(value);
    }
    const time = `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`;
    if (form === editEvent) editEvent = { ...form, time };
    else newEvent = { ...form, time };
  }

  /** @param {string} value */
  function timeParts(value) {
    const [rawHour, rawMinute] = (value || '10:00').split(':').map(Number);
    const hour = rawHour % 12 || 12;
    return { hour, minute: rawMinute, period: rawHour >= 12 ? 'PM' : 'AM' };
  }

  const timeOptions = Array.from({ length: 35 }, (_, index) => {
    const totalMinutes = 6 * 60 + index * 30;
    const hour = Math.floor(totalMinutes / 60);
    const minute = totalMinutes % 60;
    const period = hour >= 12 ? 'PM' : 'AM';
    const displayHour = hour % 12 || 12;
    return { value: `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`, label: `${displayHour}:${String(minute).padStart(2, '0')} ${period}` };
  });

  /** @param {string} value */
  function formatDate(value) {
    if (!value) return '';
    const date = new Date(`${value}T12:00:00`);
    return date.toLocaleDateString('en-IN', { weekday: 'short', day: 'numeric', month: 'short' });
  }

  /** @param {string} value */
  function formatTime(value) {
    const match = /^([0-9]{2}):([0-9]{2})$/.exec(value || '');
    if (!match) return '';
    const hour = Number(match[1]);
    const minute = match[2];
    const period = hour >= 12 ? 'PM' : 'AM';
    return `${hour % 12 || 12}:${minute} ${period}`;
  }

  /** @param {{ dateValue: string, time: string }} form */
  function displayDateTime(form) {
    return `${formatDate(form.dateValue)}, ${formatTime(form.time)}`;
  }

  /** @param {EventForm} form */
  function datePickerLabel(form) {
    return form.dateValue ? formatDate(form.dateValue) : 'Choose a date';
  }

  /** @param {EventForm} form */
  function timePickerLabel(form) {
    return form.time ? formatTime(form.time) : 'Choose a time';
  }

  /** @param {string} id */
  function navigate(id) {
    active = id;
    hasSelectedEvent = false;
    selectedEvent = null;
    selectedFriend = null;
    showCreate = false;
    showEdit = false;
    calendarOpen = false;
    timeWheelOpen = false;
    eventSportOpen = false;
    eventSkillOpen = false;
    visibilityOpen = false;
    showNotifications = false;
    showRating = false;
    ratingEvent = null;
    showChat = false;
    chatEvent = null;
    chatDraft = '';
    profileSheet = null;
  }

  /** @param {MockEvent} event */
  function openEvent(event) {
    selectedEvent = event;
    hasSelectedEvent = true;
  }

  function closeEvent() {
    hasSelectedEvent = false;
    showEdit = false;
    calendarOpen = false;
    timeWheelOpen = false;
  }

  /** @param {PointerEvent | TouchEvent} event */
  function focusFormControl(event) {
    const element = /** @type {HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement | null} */ (event.currentTarget);
    if (!element || typeof element.focus !== 'function') return;
    window.setTimeout(() => {
      if (document.activeElement !== element) element.focus({ preventScroll: true });
    }, 0);
  }

  /** @param {string} playerId */
  function decreasePlayerRating(playerId) {
    const current = ratingDrafts[playerId]?.stars ?? 3;
    setPlayerRating(playerId, current - 1);
  }

  /** @param {string} playerId */
  function increasePlayerRating(playerId) {
    const current = ratingDrafts[playerId]?.stars ?? 3;
    setPlayerRating(playerId, current + 1);
  }

  function logout() {
    clearSession();
    goto('/login');
  }

  function updateSelectedEvent() {
    if (!selectedEvent) return;
    eventList = [...eventList];
  }

  /** @param {any} event */
  function isChatAvailable(event) {
    return Boolean(event && joinedEventIds.has(event.id) && event.status !== 'completed' && event.status !== 'cancelled');
  }

  $: chatEvents = eventList.filter((event) => joinedEventIds.has(event.id) && event.status !== 'completed' && event.status !== 'cancelled');
  $: hasActiveChats = chatEvents.length > 0;

  function openChatHub() {
    showChat = true;
    chatEvent = null;
    chatDraft = '';
  }

  function joinSelectedEvent() {
    if (!selectedEvent || selectedEvent.status === 'cancelled' || selectedEvent.status === 'completed') return;
    if (selectedEvent.members >= selectedEvent.capacity) {
      notice = 'This game is full';
      return;
    }
    if (selectedEvent.visibility === 'Private') {
      selectedEvent.pendingRequests = (selectedEvent.pendingRequests ?? 0) + 1;
      updateSelectedEvent();
      notice = 'Join request sent';
      return;
    }
    selectedEvent.members += 1;
    joinedEventIds = new Set([...joinedEventIds, selectedEvent.id]);
    selectedEvent.status = selectedEvent.members >= selectedEvent.capacity ? 'full' : 'upcoming';
    updateSelectedEvent();
    notice = 'You joined the game';
    setTimeout(() => (notice = ''), 1800);
  }

  function leaveSelectedEvent() {
    if (!selectedEvent || selectedEvent.host === session?.name) return;
    const event = selectedEvent;
    event.members = Math.max(0, event.members - 1);
    joinedEventIds = new Set([...joinedEventIds].filter((id) => id !== event.id));
    event.status = 'upcoming';
    updateSelectedEvent();
    notice = 'You left the game';
    setTimeout(() => (notice = ''), 1800);
  }

  function addMockPlayer() {
    if (!selectedEvent) return;
    if (selectedEvent.members >= selectedEvent.capacity) {
      notice = 'Game is full';
      setTimeout(() => (notice = ''), 1800);
      return;
    }
    selectedEvent.members += 1;
    selectedEvent.status = selectedEvent.members >= selectedEvent.capacity ? 'full' : 'upcoming';
    updateSelectedEvent();
    notice = 'Demo player added';
    setTimeout(() => (notice = ''), 1800);
  }

  function startCreate() {
    newEvent = emptyEventForm();
    calendarOpen = false;
    timeWheelOpen = false;
    showCreate = true;
  }

  /** @param {EventForm} form @returns {MockEvent} */
  function buildEventFromForm(form) {
    return {
      id: Date.now(),
      sport: form.sport,
      title: form.title.trim(),
      date: displayDateTime(form),
      dateValue: form.dateValue,
      time: form.time,
      location: form.location.trim(),
      host: session?.name ?? 'Sanjay',
      members: 1,
      capacity: Number(form.capacity),
      skill: form.skill,
      color: form.sport === 'Football' ? 'blue' : form.sport === 'Badminton' ? 'peach' : form.sport === 'Basketball' ? 'lavender' : 'mint',
      description: form.description.trim() || 'A new Huddl event.',
      visibility: form.visibility,
      status: 'upcoming',
      pendingRequests: 0
    };
  }

  function create() {
    if (!newEvent.title || !newEvent.dateValue || !newEvent.time || !newEvent.location || Number(newEvent.capacity) < 2) {
      notice = 'Fill in all required fields';
      return;
    }
    const created = buildEventFromForm(newEvent);
    eventList = [created, ...eventList];
    joinedEventIds = new Set([...joinedEventIds, created.id]);
    chatMessages = { ...chatMessages, [String(created.id)]: [] };
    showCreate = false;
    newEvent = emptyEventForm();
    active = 'home';
    notice = 'Event created';
    setTimeout(() => (notice = ''), 1800);
  }

  /** @param {MockEvent | null} event */
  function startEdit(event) {
    if (!event) return;
    const [datePart, timePart] = event.date.split(', ');
    const option = dateOptions.find((item) => item.label === datePart);
    editEvent = {
      title: event.title,
      sport: event.sport,
      dateValue: event.dateValue ?? option?.value ?? '',
      time: event.time ?? timeOptions.find((item) => item.label === timePart)?.value ?? '',
      location: event.location,
      capacity: event.capacity,
      skill: event.skill,
      visibility: event.visibility ?? 'Public',
      description: event.description
    };
    calendarOpen = false;
    timeWheelOpen = false;
    showEdit = true;
  }

  function saveEdit() {
    if (!selectedEvent || !editEvent.title || !editEvent.dateValue || !editEvent.time || !editEvent.location) {
      notice = 'Fill in all required fields';
      return;
    }
    selectedEvent.title = editEvent.title.trim();
    selectedEvent.sport = editEvent.sport;
    selectedEvent.date = displayDateTime(editEvent);
    selectedEvent.dateValue = editEvent.dateValue;
    selectedEvent.time = editEvent.time;
    selectedEvent.location = editEvent.location.trim();
    selectedEvent.capacity = Math.max(Number(editEvent.capacity), selectedEvent.members);
    selectedEvent.skill = editEvent.skill;
    selectedEvent.visibility = editEvent.visibility;
    selectedEvent.description = editEvent.description.trim() || 'A Huddl event.';
    selectedEvent.color = editEvent.sport === 'Football' ? 'blue' : editEvent.sport === 'Badminton' ? 'peach' : editEvent.sport === 'Basketball' ? 'lavender' : 'mint';
    updateSelectedEvent();
    showEdit = false;
    notice = 'Event updated';
    setTimeout(() => (notice = ''), 1800);
  }

  function cancelSelectedEvent() {
    if (!selectedEvent) return;
    const event = selectedEvent;
    event.status = 'cancelled';
    joinedEventIds = new Set([...joinedEventIds].filter((id) => id !== event.id));
    updateSelectedEvent();
    hasSelectedEvent = false;
    notice = 'Event cancelled';
    setTimeout(() => (notice = ''), 1800);
  }

  function finishSelectedEvent() {
    if (!selectedEvent) return;
    selectedEvent.status = 'completed';
    updateSelectedEvent();
    ratingEvent = selectedEvent;
    showRating = true;
    notice = 'Event marked complete';
    setTimeout(() => (notice = ''), 1800);
  }

  function acceptRequest() {
    if (!selectedEvent || !selectedEvent.pendingRequests) return;
    if (selectedEvent.members >= selectedEvent.capacity) {
      notice = 'Game is already full';
      return;
    }
    selectedEvent.pendingRequests -= 1;
    selectedEvent.members += 1;
    joinedEventIds = new Set([...joinedEventIds, selectedEvent.id]);
    selectedEvent.status = selectedEvent.members >= selectedEvent.capacity ? 'full' : 'upcoming';
    updateSelectedEvent();
    notice = 'Request accepted';
    setTimeout(() => (notice = ''), 1800);
  }

  function rejectRequest() {
    if (!selectedEvent || !selectedEvent.pendingRequests) return;
    selectedEvent.pendingRequests -= 1;
    updateSelectedEvent();
    notice = 'Request declined';
    setTimeout(() => (notice = ''), 1800);
  }

  /** @param {MockEvent} event */
  function openRating(event) {
    if (event.ratingsSubmitted) return;
    ratingEvent = event;
    showRating = true;
    /** @type {Record<string, RatingDraft>} */
    const drafts = {};
    for (let index = 0; index < Math.max(0, event.members - 1); index += 1) {
      drafts[`${event.id}-${index + 1}`] = { stars: 0, showedUp: true, skillMatch: true };
    }
    ratingDrafts = drafts;
  }

  /** @param {MockEvent} event */
  function openChat(event) {
    if (!isChatAvailable(event)) return;
    chatEvent = event;
    showChat = true;
    chatDraft = '';
    if (!chatMessages[String(event.id)]) chatMessages = { ...chatMessages, [String(event.id)]: [] };
  }

  function closeChat() {
    showChat = false;
    chatEvent = null;
    chatDraft = '';
  }

  function sendChatMessage() {
    if (!chatEvent || !chatDraft.trim()) return;
    const key = String(chatEvent.id);
    const message = { id: Date.now(), sender: session?.name ?? 'You', text: chatDraft.trim(), time: new Date().toLocaleTimeString('en-IN', { hour: 'numeric', minute: '2-digit' }), mine: true };
    chatMessages = { ...chatMessages, [key]: [...(chatMessages[key] ?? []), message] };
    chatDraft = '';
  }

  function openSelectedEventRating() {
    if (!selectedEvent) return;
    openRating(selectedEvent);
  }

  /** @param {string} playerId @param {number} stars */
  function setPlayerRating(playerId, stars) {
    const nextStars = Math.trunc(Number(stars));
    if (!Number.isFinite(nextStars) || nextStars < 1 || nextStars > 5) return;
    const current = ratingDrafts[playerId] ?? { stars: 0, showedUp: true, skillMatch: true };
    ratingDrafts = {
      ...ratingDrafts,
      [playerId]: { ...current, stars: nextStars }
    };
  }


  /** @param {string} playerId @param {'showedUp' | 'skillMatch'} field */
  function toggleRatingField(playerId, field) {
    const current = ratingDrafts[playerId] ?? { stars: 0, showedUp: true, skillMatch: true };
    const nextValue = !current[field];
    ratingDrafts = {
      ...ratingDrafts,
      [playerId]: { ...current, [field]: nextValue, ...(field === 'showedUp' && !nextValue ? { stars: 0, skillMatch: false } : {}) }
    };
  }

  function submitRatings() {
    const players = Object.values(ratingDrafts);
    const missingRatings = players.filter((item) => item.showedUp && item.stars < 1).length;
    if (missingRatings > 0) {
      notice = `Rate the ${missingRatings} player${missingRatings === 1 ? '' : 's'} who showed up`;
      setTimeout(() => (notice = ''), 1800);
      return;
    }
    if (ratingEvent) {
      ratingEvent.ratingsSubmitted = true;
      eventList = [...eventList];
    }
    showRating = false;
    ratingEvent = null;
    notice = 'Ratings submitted';
    setTimeout(() => (notice = ''), 1800);
  }

  function openNotifications() {
    showNotifications = true;
    showRating = false;
  }

  /** @param {number} id */
  function markNotificationRead(id) {
    notifications = notifications.map((item) => item.id === id ? { ...item, unread: false } : item);
  }

  function markAllNotificationsRead() {
    notifications = notifications.map((item) => ({ ...item, unread: false }));
  }

  /** @param {FriendCandidate} candidate */
  function sendFriendRequest(candidate) {
    friendCandidates = friendCandidates.filter((friend) => friend.id !== candidate.id);
    notice = `Request sent to ${candidate.name}`;
    setTimeout(() => (notice = ''), 1800);
  }

  /** @param {FriendCandidate} request */
  function acceptFriendRequest(request) {
    incomingRequests = incomingRequests.filter((friend) => friend.id !== request.id);
    friendList = [...friendList, { ...request, status: 'new' }];
    notice = `${request.name} is now your friend`;
    setTimeout(() => (notice = ''), 1800);
  }

  /** @param {FriendCandidate} request */
  function declineFriendRequest(request) {
    incomingRequests = incomingRequests.filter((friend) => friend.id !== request.id);
    notice = 'Request declined';
    setTimeout(() => (notice = ''), 1800);
  }

  /** @param {MockFriend} friend */
  function removeFriend(friend) {
    friendList = friendList.filter((item) => item.id !== friend.id);
    selectedFriend = null;
    notice = `${friend.name} removed from friends`;
    setTimeout(() => (notice = ''), 1800);
  }

  /** @param {MockFriend | FriendCandidate} friend */
  function messageFriend(friend) {
    notice = `Opened chat with ${friend.name}`;
    selectedFriend = null;
    setTimeout(() => (notice = ''), 1800);
  }

  function messageSelectedFriend() {
    if (!selectedFriend) return;
    messageFriend(selectedFriend);
  }

  function openProfileEditor() {
    profileDraft = { name: userProfile.name, handle: userProfile.handle, bio: userProfile.bio };
    profileSheet = 'profile';
  }

  function saveProfileEditor() {
    const name = profileDraft.name.trim();
    const handle = profileDraft.handle.trim().startsWith('@') ? profileDraft.handle.trim() : `@${profileDraft.handle.trim()}`;
    if (!name || !handle.slice(1)) {
      notice = 'Name and handle are required';
      setTimeout(() => (notice = ''), 1800);
      return;
    }
    userProfile = { ...userProfile, name, handle, bio: profileDraft.bio.trim() || 'Always down for a game.' };
    setProfile(userProfile);
    if (session) {
      session = { ...session, name };
      setSession(session);
    }
    profileSheet = null;
    notice = 'Profile updated';
    setTimeout(() => (notice = ''), 1800);
  }

  function openSportsEditor() {
    sportsDraft = [...userProfile.sports];
    skillsDraft = Object.fromEntries(userProfile.sports.map((sport, index) => [sport, userProfile.skills[index] ?? 'Intermediate']));
    profileSheet = 'sports';
  }

  /** @param {string} sport */
  function toggleProfileSport(sport) {
    if (sportsDraft.includes(sport)) {
      sportsDraft = sportsDraft.filter((item) => item !== sport);
      const next = { ...skillsDraft };
      delete next[sport];
      skillsDraft = next;
      return;
    }
    sportsDraft = [...sportsDraft, sport];
    skillsDraft = { ...skillsDraft, [sport]: 'Intermediate' };
  }

  function saveSportsEditor() {
    if (!sportsDraft.length) {
      notice = 'Choose at least one sport';
      setTimeout(() => (notice = ''), 1800);
      return;
    }
    userProfile = { ...userProfile, sports: sportsDraft, skills: sportsDraft.map((sport) => skillsDraft[sport] ?? 'Intermediate') };
    setProfile(userProfile);
    profileSheet = null;
    notice = 'Sports updated';
    setTimeout(() => (notice = ''), 1800);
  }

  function openAccountSettings() {
    profileSheet = 'account';
  }

  function openNotificationSettings() {
    settingsDraft = {
      showContact: userProfile.settings?.showContact ?? false,
      eventNotifications: userProfile.settings?.eventNotifications ?? true,
      friendNotifications: userProfile.settings?.friendNotifications ?? true,
      ratingNotifications: userProfile.settings?.ratingNotifications ?? true
    };
    profileSheet = 'notifications';
  }

  function saveSettings() {
    userProfile = { ...userProfile, settings: { ...settingsDraft } };
    setProfile(userProfile);
    profileSheet = null;
    notice = 'Settings saved';
    setTimeout(() => (notice = ''), 1800);
  }
</script>

<svelte:head><title>Huddl</title><meta name="description" content="Find people to play with." /></svelte:head>

{#if checkingAuth}
  <div class="auth-loading">Loading Huddl…</div>
{:else if !session}
  <div class="auth-loading">Redirecting to login…</div>
{:else}
<div class="app-shell">
  {#if hasSelectedEvent && selectedEvent}
    <main class="screen detail-screen">
      <button class="back" aria-label="Back" onclick={closeEvent}><Icon name="back" size={23}/></button>
      <div class="detail-hero {selectedEvent.color}">
        <div class="hero-row"><div><span class="pill">{selectedEvent.sport}</span><span class="muted">{selectedEvent.skill}</span></div><span class="status-pill {selectedEvent.status ?? 'upcoming'}">{selectedEvent.status === 'full' ? 'Full' : selectedEvent.status === 'completed' ? 'Completed' : selectedEvent.status === 'cancelled' ? 'Cancelled' : selectedEvent.visibility ?? 'Public'}</span></div>
        <h1>{selectedEvent.title}</h1>
        <p>{selectedEvent.description}</p>
      </div>
      <div class="detail-grid">
        <div><Icon name="calendar" size={19}/><span>{selectedEvent.date}</span></div>
        <div><Icon name="map" size={19}/><span>{selectedEvent.location}</span></div>
      </div>
      <section class="panel"><div class="panel-head"><h2>Players</h2><strong>{selectedEvent.members}/{selectedEvent.capacity}</strong></div><div class="big-progress"><span style={`width:${Math.round(selectedEvent.members/selectedEvent.capacity*100)}%`}></span></div><div class="avatars">{#each Array(selectedEvent.members) as _,i}<span>{String.fromCharCode(65+i)}</span>{/each}<span class="empty">+</span></div></section>
      <p class="host-line">Hosted by <strong>{selectedEvent.host}</strong></p>

      {#if selectedEvent.host === session?.name}
        <section class="host-actions">
          {#if selectedEvent.status === 'completed'}
            {#if !selectedEvent.ratingsSubmitted}<button class="primary" onclick={openSelectedEventRating}>Rate players</button>{/if}
          {:else if selectedEvent.status === 'upcoming' || selectedEvent.status === 'full'}
            <button class="secondary" onclick={() => startEdit(selectedEvent)}><Icon name="edit" size={17}/>Edit event</button>
            <button class="secondary" onclick={finishSelectedEvent}><Icon name="check" size={17}/>Finish event</button>
            <button class="danger" onclick={cancelSelectedEvent}><Icon name="close" size={17}/>Cancel event</button>
            <div class="mock-tools"><div><strong>Test mode</strong><span>Add a demo player to test post-game ratings.</span></div><button class="tiny" onclick={addMockPlayer}>Add player</button></div>
          {/if}
          {#if (selectedEvent.pendingRequests ?? 0) > 0}
            <div class="request-box"><div><strong>{selectedEvent.pendingRequests} join request{selectedEvent.pendingRequests === 1 ? '' : 's'}</strong><span>People want to join this private game.</span></div><div class="request-actions"><button class="accept" onclick={acceptRequest}>Accept</button><button class="decline" onclick={rejectRequest}>Decline</button></div></div>
          {/if}
        </section>
      {:else if selectedEvent.status === 'completed'}
        <div class="state-message">This event is completed.</div>
        {#if !selectedEvent.ratingsSubmitted}<button class="primary" onclick={openSelectedEventRating}>Rate players</button>{/if}
      {:else if selectedEvent.status === 'cancelled'}
        <div class="state-message">This event is cancelled.</div>
      {:else if selectedEvent.visibility === 'Private' && (selectedEvent.pendingRequests ?? 0) > 0}
        <div class="state-message">Your join request is pending.</div>
      {:else if selectedEvent.members >= selectedEvent.capacity}
        <div class="state-message">This game is full.</div>
      {:else}
        <div class="join-actions"><button class="primary" onclick={joinSelectedEvent}>Join game</button><button class="secondary" onclick={leaveSelectedEvent}>Leave game</button></div>
      {/if}
    </main>
  {:else if active === 'home'}
    <main class="screen">
      <header class="toolbar"><div><p class="eyebrow">HUDDL</p><h1>Find your next game.</h1></div><div class="toolbar-actions"><button class="notification-button" aria-label="Notifications" onclick={openNotifications}><Icon name="bell" size={21}/>{#if unreadNotifications > 0}<span class="notification-dot">{unreadNotifications}</span>{/if}</button><button class="avatar" aria-label="Profile" onclick={() => navigate('profile')}>{session?.name?.[0]?.toUpperCase() ?? 'S'}</button></div></header>
      <div class="filters">{#each sports as item}<button class:chosen={filter===item} onclick={() => filter=item}>{item}</button>{/each}</div>
      <section><div class="section-head"><h2>Upcoming</h2><span>{filteredEvents.length} games</span></div><div class="feed">{#each filteredEvents as event (event.id)}<EventCard {event} onclick={() => openEvent(event)}/>{/each}</div></section>
    </main>
  {:else if active === 'friends'}
    <main class="screen"><header class="page-head"><div><p class="eyebrow">COMMUNITY</p><h1>Friends</h1></div><button class="round"><Icon name="user" size={21}/></button></header>
      <div class="search"><Icon name="search" size={19}/><input bind:value={search} placeholder="Search people" onpointerup={focusFormControl} ontouchend={focusFormControl} /></div>
      {#if incomingRequests.length > 0}
        <section class="panel compact-panel"><div class="panel-head"><h2>Friend requests</h2><span class="request-count">{incomingRequests.length} waiting</span></div>{#each incomingRequests as request}<div class="request-row"><span class="friend-avatar {request.color}">{request.name[0]}</span><span class="friend-copy"><strong>{request.name}</strong><small>{request.handle} · {request.sports}</small></span><button class="request-action accept" onclick={() => acceptFriendRequest(request)}>Accept</button><button class="request-action decline" onclick={() => declineFriendRequest(request)}>Decline</button></div>{/each}</section>
      {/if}
      <section class="friends-section"><div class="section-head"><h2>Find people</h2><span>{filteredCandidates.length} results</span></div><div class="list">{#each filteredCandidates as candidate}<div class="friend-row"><button class="friend-main" onclick={() => selectedFriend = candidate}><span class="friend-avatar {candidate.color}">{candidate.name[0]}</span><span class="friend-copy"><strong>{candidate.name}</strong><small>{candidate.handle} · {candidate.sports}</small></span></button><button class="tiny" onclick={() => sendFriendRequest(candidate)}>Add</button></div>{/each}</div></section>
      <section class="friends-section"><div class="section-head"><h2>Your friends</h2><span>{filteredFriends.length} friends</span></div><div class="list">{#each filteredFriends as friend}<div class="friend-row"><button class="friend-main" onclick={() => selectedFriend = friend}><span class="friend-avatar {friend.color}">{friend.name[0]}</span><span class="friend-copy"><strong>{friend.name}</strong><small>{friend.handle} · {friend.sports}</small></span><span class="status">{friend.status}</span></button><button class="tiny" onclick={() => removeFriend(friend)}>Remove</button></div>{/each}</div></section>
    </main>
  {:else if active === 'stats'}
    <main class="screen"><header class="page-head"><div><p class="eyebrow">YOUR PLAY</p><h1>Stats</h1></div></header><div class="stat-grid"><div><strong>{stats.games}</strong><span>Games</span></div><div><strong>{stats.hosted}</strong><span>Hosted</span></div><div><strong>{stats.rating}</strong><span>Rating</span></div><div><strong>{stats.attendance}%</strong><span>Attendance</span></div></div><section class="panel"><div class="panel-head"><h2>Games by sport</h2></div>{#each stats.sports as sport}<div class="bar-row"><div><span>{sport.name}</span><strong>{sport.games}</strong></div><div class="bar"><span style={`width:${sport.games/12*100}%`}></span></div></div>{/each}</section></main>
  {:else}
    <main class="screen"><header class="profile-head"><span class="profile-avatar">{userProfile.name?.[0]?.toUpperCase() ?? session?.name?.[0]?.toUpperCase() ?? 'S'}</span><div><h1>{userProfile.name}</h1><p>{userProfile.handle}</p></div><button class="round" aria-label="Edit profile" onclick={openProfileEditor}><Icon name="edit" size={20}/></button></header><p class="bio">{userProfile.bio}</p><section class="panel"><div class="panel-head"><h2>Your sports</h2><button class="tiny" onclick={openSportsEditor}>Edit</button></div>{#each userProfile.sports as sport,i}<div class="sport-row"><span>{sport}</span><span>{userProfile.skills[i]}</span></div>{/each}</section><section class="settings"><button onclick={openAccountSettings}>Account settings <Icon name="chevron" size={18}/></button><button onclick={openNotificationSettings}>Preferences {#if unreadNotifications > 0}<span class="setting-badge">{unreadNotifications}</span>{/if}<Icon name="chevron" size={18}/></button><button onclick={openNotifications}>Notifications {#if unreadNotifications > 0}<span class="setting-badge">{unreadNotifications}</span>{/if}<Icon name="chevron" size={18}/></button><button onclick={logout}>Sign out <Icon name="chevron" size={18}/></button></section></main>
  {/if}

  {#if !hasSelectedEvent && hasActiveChats}
    <button class="chat-fab" aria-label="Open game chats" onclick={openChatHub}><Icon name="message" size={25}/></button>
  {/if}
  {#if !hasSelectedEvent}<button class="create" aria-label="Create event" onclick={startCreate}><Icon name="plus" size={29} stroke={3}/></button>{/if}

  <BottomNav {active} onNavigate={navigate}/>

  {#if showNotifications}
    <div class="scrim">
      <button class="scrim-backdrop" type="button" aria-label="Close notifications" onclick={() => showNotifications = false}></button>
      <section class="sheet notification-sheet" aria-label="Notifications">
        <div class="sheet-head"><div><p class="eyebrow">UPDATES</p><h2>Notifications</h2></div><button class="round" aria-label="Close" onclick={() => showNotifications = false}><Icon name="close" size={20}/></button></div>
        {#if notifications.length === 0}
          <div class="state-message">You're all caught up.</div>
        {:else}
          <div class="notification-list">
            {#each notifications as item (item.id)}
              <button type="button" class:unread={item.unread} class="notification-row" onclick={() => markNotificationRead(item.id)}>
                <span class="notification-icon"><Icon name="bell" size={18}/></span>
                <span class="notification-copy"><strong>{item.title}</strong><span>{item.message}</span><small>{item.time}</small></span>
                {#if item.unread}<span class="unread-dot"></span>{/if}
              </button>
            {/each}
          </div>
          {#if unreadNotifications > 0}<button class="secondary" onclick={markAllNotificationsRead}>Mark all as read</button>{/if}
        {/if}
      </section>
    </div>
  {/if}

  {#if showChat}
    <div class="scrim">
      <button class="scrim-backdrop" type="button" aria-label="Close game chats" onclick={closeChat}></button>
      <section class="sheet chat-sheet selection-sheet" aria-label="Game chats">
        {#if chatEvent}
          <div class="sheet-head chat-detail-head"><button class="back chat-back" aria-label="Back to chats" onclick={() => { chatEvent = null; chatDraft = ''; }}><Icon name="back" size={20}/></button><div><p class="eyebrow">GAME CHAT</p><h2>{chatEvent.title}</h2></div><button class="round" aria-label="Close" onclick={closeChat}><Icon name="close" size={20}/></button></div>
          <div class="chat-meta"><span>{chatEvent.members} players</span><span>Game group</span></div>
          <div class="chat-list chat-selection-list">
            {#if (chatMessages[String(chatEvent.id)] ?? []).length === 0}
              <div class="chat-empty">No messages yet. Start the conversation.</div>
            {:else}
              {#each chatMessages[String(chatEvent.id)] ?? [] as message (message.id)}
                <div class="chat-message chat-selection-row {message.mine ? 'mine' : ''}">
                  <span class="chat-avatar">{message.sender[0]}</span>
                  <div class="chat-bubble"><strong>{message.mine ? 'You' : message.sender}</strong><p>{message.text}</p><small>{message.time}</small></div>
                </div>
              {/each}
            {/if}
          </div>
          <form class="chat-composer" onsubmit={(event) => { event.preventDefault(); sendChatMessage(); }}>
            <input bind:value={chatDraft} aria-label="Message" placeholder="Message the group…" onpointerup={focusFormControl} ontouchend={focusFormControl} />
            <button type="submit" class="chat-send" aria-label="Send message"><Icon name="send" size={18}/></button>
          </form>
        {:else}
          <div class="sheet-head"><div><p class="eyebrow">HUDDL CHATS</p><h2>Your game chats</h2></div><button class="round" aria-label="Close" onclick={closeChat}><Icon name="close" size={20}/></button></div>
          <div class="chat-hub-list">
            {#each chatEvents as event (event.id)}
              <button class="chat-event-row" type="button" onclick={() => openChat(event)}>
                <span class="chat-event-icon"><Icon name="message" size={20}/></span>
                <span class="chat-event-copy"><strong>{event.title}</strong><small>{event.sport} · {event.date}</small></span>
                <Icon name="chevron" size={18}/>
              </button>
            {/each}
          </div>
        {/if}
      </section>
    </div>
  {/if}

  {#if showRating && ratingEvent}
    <div class="scrim">
      <button class="scrim-backdrop" type="button" aria-label="Close rating" onclick={() => showRating = false}></button>
      <section class="sheet rating-sheet" aria-label="Rate players">
        <div class="sheet-head"><div><p class="eyebrow">POST-GAME</p><h2>Rate players</h2></div><button class="round" aria-label="Close" onclick={() => showRating = false}><Icon name="close" size={20}/></button></div>
        <p class="sheet-note">How did everyone do in {ratingEvent.title}?</p>
        <div class="rating-list">
          {#each Array(Math.max(0, ratingEvent.members - 1)) as _, index}
            {@const playerId = `${ratingEvent.id}-${index + 1}`}
            {@const playerNames = ['Arjun Mehta','Meera Shah','Rohan Das','Ishita Rao','Kabir Nair','Aanya Kapoor','Dev Malhotra']}
            {@const playerName = playerNames[index] ?? `Player ${index + 1}`}
            {@const draft = ratingDrafts[playerId] ?? { stars: 0, showedUp: true, skillMatch: true }}
            <div class="rating-row">
              <div class="rating-person"><span class="friend-avatar {['peach','lavender','blue','mint'][index % 4]}">{playerName[0]}</span><span><strong>{playerName}</strong><small>Player {index + 1}</small></span></div>
              <div class="rating-score">
                <div class="stars" aria-label={draft.stars > 0 ? `${draft.stars} out of 5 stars` : 'No rating selected'}>
                  {#each [1, 2, 3, 4, 5] as star}
                    <span class="star-choice" class:filled={star <= draft.stars} class:selected-star={draft.stars === star} aria-hidden="true">★</span>
                  {/each}
                </div>
                <button
                  type="button"
                  class="rating-stepper"
                  aria-label={`Decrease ${playerName} rating`}
                  disabled={draft.stars <= 0}
                  onclick={() => decreasePlayerRating(playerId)}
                >−</button>
                <button
                  type="button"
                  class="rating-stepper"
                  aria-label={`Increase ${playerName} rating`}
                  onclick={() => increasePlayerRating(playerId)}
                >+</button>
              </div>
              <span class="rating-value">{draft.stars > 0 ? `${draft.stars}/5` : '—'}</span>
              <div class="rating-toggles"><button type="button" class:on={draft.showedUp} onclick={() => toggleRatingField(playerId, 'showedUp')}>Showed up</button><button type="button" class:on={draft.skillMatch} disabled={!draft.showedUp} onclick={() => toggleRatingField(playerId, 'skillMatch')}>Skill match</button></div>
            </div>
          {/each}
        </div>
        <button class="primary" onclick={submitRatings}>Submit ratings</button>
      </section>
    </div>
  {/if}

  {#if profileSheet === 'profile'}
    <div class="scrim">
      <button class="scrim-backdrop" type="button" aria-label="Close edit profile" onclick={() => profileSheet = null}></button>
      <section class="sheet" aria-label="Edit profile">
        <div class="sheet-head"><div><p class="eyebrow">PROFILE</p><h2>Edit profile</h2></div><button class="round" aria-label="Close" onclick={() => profileSheet = null}><Icon name="close" size={20}/></button></div>
        <div class="form-field"><label for="profile-name">Name</label><input id="profile-name" bind:value={profileDraft.name} placeholder="Your name" onpointerup={focusFormControl} ontouchend={focusFormControl} /></div>
        <div class="form-field"><label for="profile-handle">Handle</label><input id="profile-handle" bind:value={profileDraft.handle} placeholder="@yourhandle" onpointerup={focusFormControl} ontouchend={focusFormControl} /></div>
        <div class="form-field"><label for="profile-bio">Bio</label><textarea id="profile-bio" bind:value={profileDraft.bio} rows="3" placeholder="A short intro" onpointerup={focusFormControl} ontouchend={focusFormControl}></textarea></div>
        <button class="primary" onclick={saveProfileEditor}>Save profile</button>
      </section>
    </div>
  {/if}

  {#if profileSheet === 'sports'}
    <div class="scrim">
      <button class="scrim-backdrop" type="button" aria-label="Close sports editor" onclick={() => profileSheet = null}></button>
      <section class="sheet" aria-label="Edit sports">
        <div class="sheet-head"><div><p class="eyebrow">YOUR PLAY</p><h2>Edit sports</h2></div><button class="round" aria-label="Close" onclick={() => profileSheet = null}><Icon name="close" size={20}/></button></div>
        <div class="sport-grid profile-sport-grid selection-grid">
          {#each sports.slice(1) as sport}
            <button type="button" class:selected={sportsDraft.includes(sport)} onclick={() => toggleProfileSport(sport)}>{sport}<span>{sportsDraft.includes(sport) ? '✓' : '+'}</span></button>
          {/each}
        </div>
        {#if sportsDraft.length}
          <div class="levels profile-levels selection-section"><div class="section-head"><h2>Skill levels</h2><span>{sportsDraft.length} selected</span></div>
            {#each sportsDraft as sport}
              <div class="level-row"><strong>{sport}</strong><div>{#each skillLevels as level}<button type="button" class:active={skillsDraft[sport] === level} onclick={() => skillsDraft = { ...skillsDraft, [sport]: level }}>{level}</button>{/each}</div></div>
            {/each}
          </div>
        {/if}
        <button class="primary" onclick={saveSportsEditor}>Save sports</button>
      </section>
    </div>
  {/if}

  {#if profileSheet === 'account'}
    <div class="scrim">
      <button class="scrim-backdrop" type="button" aria-label="Close account settings" onclick={() => profileSheet = null}></button>
      <section class="sheet" aria-label="Account settings">
        <div class="sheet-head"><div><p class="eyebrow">ACCOUNT</p><h2>Account settings</h2></div><button class="round" aria-label="Close" onclick={() => profileSheet = null}><Icon name="close" size={20}/></button></div>
        <div class="setting-card"><span><strong>Email</strong><small>{session?.email ?? 'Not set'}</small></span><span class="setting-value">Verified</span></div>
        <div class="form-field"><label for="account-phone">Phone</label><input id="account-phone" bind:value={userProfile.phone} placeholder="Optional phone number" inputmode="tel" onpointerup={focusFormControl} ontouchend={focusFormControl} /></div>
        <button class="secondary" onclick={() => { notice = 'Password reset will connect to Supabase Auth'; profileSheet = null; }}>Change password</button>
        <button class="primary" onclick={() => { setProfile(userProfile); profileSheet = null; notice = 'Account saved'; setTimeout(() => (notice = ''), 1800); }}>Save account</button>
      </section>
    </div>
  {/if}

  {#if profileSheet === 'notifications'}
    <div class="scrim">
      <button class="scrim-backdrop" type="button" aria-label="Close preferences" onclick={() => profileSheet = null}></button>
      <section class="sheet" aria-label="Notification preferences">
        <div class="sheet-head"><div><p class="eyebrow">PREFERENCES</p><h2>Notification preferences</h2></div><button class="round" aria-label="Close" onclick={() => profileSheet = null}><Icon name="close" size={20}/></button></div>
        <button class="toggle-row" type="button" onclick={() => settingsDraft = { ...settingsDraft, eventNotifications: !settingsDraft.eventNotifications }}><span><strong>Event updates</strong><small>Changes, join requests and cancellations</small></span><span class:on={settingsDraft.eventNotifications} class="toggle"><span></span></span></button>
        <button class="toggle-row" type="button" onclick={() => settingsDraft = { ...settingsDraft, friendNotifications: !settingsDraft.friendNotifications }}><span><strong>Friend updates</strong><small>Requests and connection changes</small></span><span class:on={settingsDraft.friendNotifications} class="toggle"><span></span></span></button>
        <button class="toggle-row" type="button" onclick={() => settingsDraft = { ...settingsDraft, ratingNotifications: !settingsDraft.ratingNotifications }}><span><strong>Rating reminders</strong><small>Prompts after completed games</small></span><span class:on={settingsDraft.ratingNotifications} class="toggle"><span></span></span></button>
        <button class="toggle-row" type="button" onclick={() => settingsDraft = { ...settingsDraft, showContact: !settingsDraft.showContact }}><span><strong>Show contact number</strong><small>Visible on your profile when added</small></span><span class:on={settingsDraft.showContact} class="toggle"><span></span></span></button>
        <button class="primary" onclick={saveSettings}>Save preferences</button>
      </section>
    </div>
  {/if}

  {#if selectedFriend}
    <div class="scrim">
      <button class="scrim-backdrop" type="button" aria-label="Close friend profile" onclick={() => selectedFriend = null}></button>
      <section class="sheet friend-profile-sheet" aria-label="Friend profile">
        <div class="sheet-head"><div><p class="eyebrow">PROFILE</p><h2>{selectedFriend.name}</h2></div><button class="round" aria-label="Close" onclick={() => selectedFriend=null}><Icon name="close" size={20}/></button></div>
        <div class="friend-profile-card"><span class="profile-avatar {selectedFriend.color}">{selectedFriend.name[0]}</span><strong>{selectedFriend.handle}</strong><span>{selectedFriend.sports}</span></div>
        {#if 'status' in selectedFriend}<div class="state-message">Status: {selectedFriend.status}</div>{/if}
        <button class="primary" onclick={messageSelectedFriend}>Message</button>
      </section>
    </div>
  {/if}

  {#if showCreate || showEdit}
    {@const form = showEdit ? editEvent : newEvent}
    <div class="scrim">
      <button class="scrim-backdrop" type="button" aria-label="Close event form" onclick={() => { showCreate = false; showEdit = false; }}></button>
      <section class="sheet" aria-label={showEdit ? 'Edit event' : 'Create event'}>
        <div class="sheet-head"><div><p class="eyebrow">{showEdit ? 'EDIT EVENT' : 'NEW EVENT'}</p><h2>{showEdit ? 'Update your game' : 'Create a game'}</h2></div><button class="round" aria-label="Close" onclick={() => { showCreate=false; showEdit=false; }}><Icon name="close" size={20}/></button></div>
        <div class="form-field"><label for="event-title">Title</label><input id="event-title" bind:value={form.title} placeholder="e.g. Friday Night Football" onpointerup={focusFormControl} ontouchend={focusFormControl} /></div>
        <div class="form-field selector-field"><span class="field-label">Sport</span><button type="button" class="choice-button" onclick={() => { eventSportOpen = !eventSportOpen; eventSkillOpen = false; visibilityOpen = false; }}><span><strong>{form.sport}</strong><small>Choose the game you are playing</small></span><Icon name="chevron" size={17}/></button>{#if eventSportOpen}<div class="choice-popover sport-popover"><div class="choice-grid">{#each sports.slice(1) as sport}<button type="button" class:selected-choice={form.sport === sport} onclick={() => { if (showEdit) editEvent = { ...form, sport }; else newEvent = { ...form, sport }; eventSportOpen = false; }}><span>{sport}</span><span class="choice-check">{form.sport === sport ? '✓' : ''}</span></button>{/each}</div></div>{/if}</div>
        <div class="two picker-row">
          <div class="picker-field">
            <span class="picker-label">Date</span>
            <button type="button" class="picker-button" class:placeholder={!form.dateValue} aria-label={form.dateValue ? `Change date, ${formatDate(form.dateValue)}` : 'Set date'} onclick={() => openCalendar(form)}>
              <Icon name="calendar" size={18}/>
              <span class="picker-button-copy"><strong>{form.dateValue ? formatDate(form.dateValue) : 'Set date'}</strong><small>{form.dateValue ? 'Tap to change' : 'Choose a date'}</small></span>
              <Icon name="chevron" size={16}/>
            </button>
          </div>
          <div class="picker-field">
            <span class="picker-label">Time</span>
            <button type="button" class="picker-button" class:placeholder={!form.time} aria-label={form.time ? `Change time, ${formatTime(form.time)}` : 'Set time'} onclick={() => openTimeWheel(form)}>
              <Icon name="clock" size={18}/>
              <span class="picker-button-copy"><strong>{form.time ? formatTime(form.time) : 'Set time'}</strong><small>{form.time ? 'Tap to change' : 'Choose a time'}</small></span>
              <Icon name="chevron" size={16}/>
            </button>
          </div>
        </div>

        {#if calendarOpen}
          <div class="picker-popover calendar-popover">
            <div class="calendar-head">
              <button type="button" class="calendar-nav" aria-label="Previous month" onclick={() => moveCalendar(-1)}><Icon name="back" size={17}/></button>
              <strong>{calendarMonth.toLocaleDateString('en-IN', { month: 'long', year: 'numeric' })}</strong>
              <button type="button" class="calendar-nav" aria-label="Next month" onclick={() => moveCalendar(1)}><Icon name="chevron" size={17}/></button>
            </div>
            <div class="weekdays">{#each ['S','M','T','W','T','F','S'] as day}<span>{day}</span>{/each}</div>
            <div class="calendar-grid">
              {#each calendarDays as cell}
                {#if cell}
                  <button type="button" class:selected={form.dateValue === cell.value} class:disabled={isPastDate(cell.value)} disabled={isPastDate(cell.value)} onclick={() => chooseDate(form, cell.value)}>{cell.day}</button>
                {:else}
                  <span></span>
                {/if}
              {/each}
            </div>
          </div>
        {/if}

        {#if timeWheelOpen}
          {@const parts = timeParts(form.time)}
          <div class="picker-popover time-popover">
            <div class="time-wheel">
              <div class="wheel-column period-wheel" bind:this={periodWheel} onscroll={(event) => handleWheelScroll(form, 'period', event)}>
                <div class="wheel-spacer"></div>
                {#each ['AM','PM'] as period}
                  <button type="button" class:active-wheel={parts.period === period} onclick={() => { setTimePart(form, 'period', period); scrollWheelTo(periodWheel, period === 'PM' ? 1 : 0); }}>{period}</button>
                {/each}
                <div class="wheel-spacer"></div>
              </div>
              <div class="wheel-column" bind:this={hourWheel} onscroll={(event) => handleWheelScroll(form, 'hour', event)}>
                <div class="wheel-spacer"></div>
                {#each Array(12) as _, index}
                  {@const hour = index + 1}
                  <button type="button" class:active-wheel={parts.hour === hour} onclick={() => { setTimePart(form, 'hour', hour); scrollWheelTo(hourWheel, index); }}>{String(hour).padStart(2, '0')}</button>
                {/each}
                <div class="wheel-spacer"></div>
              </div>
              <div class="wheel-column" bind:this={minuteWheel} onscroll={(event) => handleWheelScroll(form, 'minute', event)}>
                <div class="wheel-spacer"></div>
                {#each Array(12) as _, index}
                  {@const minute = index * 5}
                  <button type="button" class:active-wheel={parts.minute === minute} onclick={() => { setTimePart(form, 'minute', minute); scrollWheelTo(minuteWheel, index); }}>{String(minute).padStart(2, '0')}</button>
                {/each}
                <div class="wheel-spacer"></div>
              </div>
              <div class="wheel-fade top"></div><div class="wheel-fade bottom"></div><div class="wheel-selection"></div>
            </div>
            <button type="button" class="wheel-done" onclick={() => timeWheelOpen = false}>Done · {formatTime(form.time || '10:00')}</button>
          </div>
        {/if}
        <div class="form-field"><label for="event-capacity">Players</label><input id="event-capacity" type="number" min="2" max="30" bind:value={form.capacity} onpointerup={focusFormControl} ontouchend={focusFormControl} /></div>
        <div class="form-field selector-field"><span class="field-label">Visibility</span><button type="button" class="choice-button" onclick={() => { eventSkillOpen = false; eventSportOpen = false; visibilityOpen = !visibilityOpen; }}><span><strong>{form.visibility}</strong><small>{form.visibility === 'Public' ? 'Anyone can find and join' : 'People request access to join'}</small></span><Icon name="chevron" size={17}/></button>{#if visibilityOpen}<div class="choice-popover visibility-popover"><div class="choice-list">{#each ['Public','Private'] as visibility}<button type="button" class:selected-choice={form.visibility === visibility} onclick={() => { if (showEdit) editEvent = { ...form, visibility }; else newEvent = { ...form, visibility }; visibilityOpen = false; }}><span class="choice-option-icon">{visibility === 'Public' ? 'P' : 'R'}</span><span class="choice-option-copy"><strong>{visibility}</strong><small>{visibility === 'Public' ? 'Anyone can find and join' : 'Only people you approve can join'}</small></span><span class="choice-check">{form.visibility === visibility ? '✓' : ''}</span></button>{/each}</div></div>{/if}</div>
        <div class="form-field"><label for="event-location">Location</label><input id="event-location" bind:value={form.location} placeholder="Court, park or arena" onpointerup={focusFormControl} ontouchend={focusFormControl} /></div>
        <div class="form-field selector-field"><span class="field-label">Skill level</span><button type="button" class="choice-button" onclick={() => { eventSkillOpen = !eventSkillOpen; eventSportOpen = false; visibilityOpen = false; }}><span><strong>{form.skill}</strong><small>Set the level expected for this game</small></span><Icon name="chevron" size={17}/></button>{#if eventSkillOpen}<div class="choice-popover skill-popover"><div class="choice-list skill-option-list">{#each skillLevels as level}<button type="button" class:selected-choice={form.skill === level} onclick={() => { if (showEdit) editEvent = { ...form, skill: level }; else newEvent = { ...form, skill: level }; eventSkillOpen = false; }}><span class="choice-option-icon">{['Beginner','Amateur','Intermediate','Seasoned','Professional'].indexOf(level) + 1}</span><span class="choice-option-copy"><strong>{level}</strong><small>{level === 'Beginner' ? 'New to the sport' : level === 'Amateur' ? 'Some experience and basic confidence' : level === 'Intermediate' ? 'Comfortable playing full games' : level === 'Seasoned' ? 'Strong, experienced player' : 'High-level competitive player'}</small></span><span class="choice-check">{form.skill === level ? '✓' : ''}</span></button>{/each}</div></div>{/if}</div>
        <div class="form-field"><label for="event-description">Description</label><textarea id="event-description" bind:value={form.description} placeholder="Anything players should know?" rows="3" onpointerup={focusFormControl} ontouchend={focusFormControl}></textarea></div>
        <button class="primary" onclick={showEdit ? saveEdit : create}>{showEdit ? 'Save changes' : 'Create event'}</button>
      </section>
    </div>
  {/if}
  {#if notice}<div class="toast">{notice}</div>{/if}
</div>
{/if}

<style>
  .auth-loading{min-height:100vh;background:#fbfbfb;display:grid;place-items:center;color:#777;font:800 12px Quicksand,sans-serif}
  :global(*){box-sizing:border-box}:global(html,body){margin:0;min-height:100%;background:#161616;color:#171717;font-family:Nunito,Arial,sans-serif}:global(button),:global(input),:global(select),:global(textarea){font:inherit}:global(button){cursor:pointer}.app-shell{min-height:100vh;width:min(100%,430px);margin:0 auto;background:#fbfbfb;position:relative}.screen{min-height:100vh;padding:25px 16px 130px}.toolbar,.page-head,.profile-head,.sheet-head,.panel-head{display:flex;align-items:center;justify-content:space-between}.toolbar{margin-bottom:22px;gap:16px}.eyebrow{margin:0 0 5px;font:800 12px Quicksand,sans-serif;letter-spacing:.09em}.toolbar h1,.page-head h1{margin:0;font:900 28px/1.05 Nunito,sans-serif;letter-spacing:-.025em}.avatar,.round{border:2px solid #171717;background:#ffe5d4;border-radius:50%;width:44px;height:44px;display:grid;place-items:center;font-weight:900;box-shadow:-4px 5px 0 #a1a2a4}.round{background:#fff;box-shadow:none;width:42px;height:42px}.filters{display:flex;gap:8px;overflow:auto;scrollbar-width:none;margin-bottom:28px;padding:3px 2px 8px}.filters::-webkit-scrollbar{display:none}.filters button,.pill{border:2px solid #171717;background:#fff;border-radius:999px;padding:9px 14px;font:700 13px Quicksand,sans-serif;letter-spacing:.005em;word-spacing:.02em;white-space:nowrap}.filters .chosen{background:#e9e5ff;box-shadow:-3px 4px 0 #a1a2a4}.section-head{display:flex;align-items:baseline;justify-content:space-between;margin-bottom:15px}.section-head h2,.panel h2{margin:0;font:900 21px Nunito,sans-serif}.section-head span,.muted{color:#777;font:700 12px Quicksand,sans-serif}.feed{display:grid;gap:18px}.create{position:fixed;right:max(24px,calc(50% - 191px));bottom:103px;width:54px;height:54px;border:2px solid #171717;border-radius:18px;background:#dcecff;display:grid;place-items:center;box-shadow:-5px 6px 0 #a1a2a4;z-index:71}.chat-fab{position:fixed;left:max(24px,calc(50% - 191px));bottom:103px;width:54px;height:54px;border:2px solid #171717;border-radius:18px;background:#e9e5ff;display:grid;place-items:center;box-shadow:5px 6px 0 #a1a2a4;z-index:71;touch-action:manipulation;-webkit-tap-highlight-color:transparent}.page-head{margin-bottom:20px}.search{height:48px;border:2px solid #171717;border-radius:17px;background:#fff;display:flex;align-items:center;gap:9px;padding:0 13px;box-shadow:-3px 4px 0 #ddd;margin-bottom:15px}.search input{border:0;outline:0;background:transparent;width:100%;font:700 14px Quicksand,sans-serif}.request{border:2px solid #171717;border-radius:20px;background:#f1edff;padding:13px 14px;display:flex;justify-content:space-between;align-items:center;margin-bottom:20px;box-shadow:-4px 5px 0 #a1a2a4}.request div{display:grid;gap:3px}.request span{font:700 11px Quicksand;color:#777}.tiny{border:1.5px solid #171717;border-radius:999px;background:#fff;padding:7px 11px;font:800 11px Quicksand}.list{display:grid;gap:9px}.compact-panel{padding:15px;margin-bottom:22px}.compact-panel .panel-head{margin-bottom:10px}.request-count{font:800 11px Quicksand;color:#777}.request-row{display:grid;grid-template-columns:44px minmax(0,1fr) auto auto;align-items:center;gap:7px;padding:9px 0;border-top:1px solid #ddd}.request-row:first-of-type{border-top:0}.request-action{border:1.5px solid #171717;border-radius:999px;padding:7px 9px;font:800 10px Quicksand}.request-action.accept{background:#ddf3e7}.request-action.decline{background:#fff}.friends-section{margin-bottom:24px}.friend-main{border:0;background:transparent;padding:0;display:flex;align-items:center;text-align:left;gap:11px;min-width:0;flex:1}.friend-row{border:0;background:#fff;border-bottom:1px solid #ddd;padding:9px 2px;display:flex;align-items:center;text-align:left;gap:9px}.friend-profile-sheet{text-align:left}.friend-profile-card{display:grid;justify-items:center;gap:7px;padding:10px 0 20px}.friend-profile-card .profile-avatar{width:78px;height:78px;flex-basis:78px;font-size:25px}.friend-profile-card strong{font:900 18px Nunito}.friend-profile-card>span:last-child{font:700 12px Quicksand;color:#777}.friend-avatar,.profile-avatar{width:44px;height:44px;border:2px solid #171717;border-radius:50%;display:grid;place-items:center;font-weight:900;flex:0 0 44px}.friend-avatar.blue{background:#dcecff}.friend-avatar.peach{background:#ffe5d4}.friend-avatar.lavender{background:#e9e5ff}.friend-avatar.mint{background:#ddf3e7}.friend-copy{display:grid;gap:2px;flex:1}.friend-copy strong{font:900 15px Nunito}.friend-copy small,.status{font:700 11px Quicksand;color:#777}.status{font-size:10px}.stat-grid{display:grid;grid-template-columns:1fr 1fr;gap:11px;margin:24px 0 20px}.stat-grid div{background:#fff;border:2px solid #171717;border-radius:20px;padding:17px;box-shadow:-4px 5px 0 #a1a2a4;display:grid;gap:3px}.stat-grid strong{font:900 27px Nunito}.stat-grid span{font:700 11px Quicksand;color:#777}.panel{background:#fff;border:2px solid #171717;border-radius:22px;padding:17px;box-shadow:-5px 6px 0 #a1a2a4;margin-bottom:18px}.panel-head{margin-bottom:16px}.panel-head strong{font:900 13px Quicksand}.big-progress,.bar{height:9px;background:#eee;border:1.5px solid #171717;border-radius:99px;overflow:hidden}.big-progress span,.bar span{display:block;height:100%;background:#7e9fe7;border-radius:99px}.avatars{display:flex;margin-top:15px}.avatars span{width:31px;height:31px;border:2px solid #171717;border-radius:50%;background:#ffe5d4;display:grid;place-items:center;font:800 10px Quicksand;margin-right:-5px}.avatars .empty{background:#fff}.bar-row{margin-top:14px}.bar-row>div:first-child{display:flex;justify-content:space-between;font:700 12px Quicksand;margin-bottom:5px}.profile-head{justify-content:flex-start;gap:12px}.profile-head .round{margin-left:auto}.profile-avatar{width:62px;height:62px;flex-basis:62px;background:#ffe5d4;font-size:20px}.profile-head h1{margin:0;font:900 22px Nunito}.profile-head p,.bio{margin:3px 0 0;color:#777;font:700 12px Quicksand}.bio{margin:20px 0}.sport-row{display:flex;justify-content:space-between;padding:12px 0;border-top:1px solid #ddd;font:800 13px Quicksand}.sport-row span:last-child{color:#777}.settings{display:grid;border:2px solid #171717;border-radius:20px;background:#fff;overflow:hidden;box-shadow:-4px 5px 0 #a1a2a4}.settings button{border:0;border-bottom:1px solid #ddd;background:#fff;padding:16px;text-align:left;display:flex;justify-content:space-between;align-items:center;font:800 13px Quicksand}.settings button:last-child{border-bottom:0;color:#b34a4a}.detail-screen{padding-top:20px}.back{width:43px;height:43px;border:2px solid #171717;border-radius:50%;background:#fff;display:grid;place-items:center;margin-bottom:16px}.detail-hero{border:2px solid #171717;border-radius:25px;padding:19px;box-shadow:-6px 7px 0 #a1a2a4}.detail-hero.blue{background:#eef6ff}.detail-hero.peach{background:#fff0e7}.detail-hero.lavender{background:#f2efff}.detail-hero.mint{background:#e9f8f0}.hero-row{display:flex;align-items:center;justify-content:space-between;gap:10px}.hero-row>div{display:flex;align-items:center;gap:8px}.status-pill{border:1.5px solid #171717;border-radius:999px;padding:5px 8px;background:#fff;font:800 10px Quicksand}.status-pill.full{background:#ffe9bf}.status-pill.completed{background:#ddf3e7}.status-pill.cancelled{background:#ffe1e1}.detail-hero h1{font:900 30px/1.02 Nunito;margin:18px 0 10px;letter-spacing:-.03em}.detail-hero p{margin:0;color:#555;font:700 13px/1.45 Quicksand}.detail-grid{display:grid;grid-template-columns:1fr 1fr;gap:9px;margin:17px 0}.detail-grid div{display:flex;align-items:center;gap:7px;background:#fff;border:2px solid #171717;border-radius:17px;padding:12px;font:700 11px Quicksand}.host-line{margin:4px 3px 18px;color:#777;font:700 12px Quicksand}.host-line strong{color:#171717}.primary{width:100%;border:2px solid #171717;border-radius:18px;background:#171717;color:#fff;padding:14px;font:900 14px Quicksand;box-shadow:-5px 6px 0 #a1a2a4}.join-actions{display:grid;gap:10px}.secondary,.danger{width:100%;border:2px solid #171717;border-radius:17px;background:#fff;color:#171717;padding:12px;font:900 13px Quicksand;display:flex;align-items:center;justify-content:center;gap:7px}.danger{background:#ffe7e7}.host-actions{display:grid;gap:10px}.request-box{border:2px solid #171717;border-radius:19px;background:#f1edff;padding:14px;display:grid;gap:12px;box-shadow:-4px 5px 0 #a1a2a4}.request-box>div:first-child{display:grid;gap:4px}.request-box strong{font:900 14px Nunito}.request-box span{font:700 11px Quicksand;color:#777}.request-actions{display:grid;grid-template-columns:1fr 1fr;gap:8px}.accept,.decline{border:1.5px solid #171717;border-radius:13px;padding:9px;font:900 11px Quicksand;background:#ddf3e7}.decline{background:#fff}.state-message{border:2px solid #171717;border-radius:17px;background:#fff;padding:14px;text-align:center;font:800 12px Quicksand;box-shadow:-3px 4px 0 #ddd}.mock-tools{border:1.5px dashed #777;border-radius:16px;background:#f8f8f8;padding:10px 11px;display:flex;align-items:center;justify-content:space-between;gap:10px}.mock-tools>div{display:grid;gap:3px}.mock-tools strong{font:900 11px Quicksand}.mock-tools span{font:700 10px/1.3 Quicksand;color:#777}.mock-tools .tiny{flex:0 0 auto}
.toolbar-actions{display:flex;align-items:center;gap:10px}.notification-button{position:relative;width:44px;height:44px;border:2px solid #171717;border-radius:50%;background:#fff;display:grid;place-items:center;box-shadow:-4px 5px 0 #a1a2a4}.notification-dot{position:absolute;right:-4px;top:-4px;min-width:18px;height:18px;padding:0 4px;border:1.5px solid #171717;border-radius:99px;background:#ffe5d4;display:grid;place-items:center;font:900 9px Quicksand}.setting-badge{margin-left:auto;min-width:20px;height:20px;padding:0 5px;border:1.5px solid #171717;border-radius:99px;background:#dcecff;display:grid;place-items:center;font:900 9px Quicksand}.notification-list{display:grid;gap:8px;margin-bottom:12px}.notification-row{width:100%;border:2px solid #171717;border-radius:17px;background:#fff;padding:12px;display:grid;grid-template-columns:38px minmax(0,1fr) 8px;gap:10px;text-align:left;align-items:center}.notification-row.unread{background:#eef6ff}.notification-icon{width:38px;height:38px;border:1.5px solid #171717;border-radius:13px;background:#fff;display:grid;place-items:center}.notification-copy{display:grid;gap:3px}.notification-copy strong{font:900 14px Nunito}.notification-copy span{font:700 11px/1.35 Quicksand;color:#555}.notification-copy small{font:700 10px Quicksand;color:#888}.unread-dot{width:7px;height:7px;border-radius:50%;background:#7e9fe7;border:1px solid #171717}.chat-sheet{max-height:88vh}.chat-meta{display:flex;gap:8px;margin:-8px 0 14px}.chat-meta span{border:1.5px solid #171717;border-radius:999px;background:#fff;padding:6px 9px;font:800 10px Quicksand;color:#666}.chat-list{display:grid;gap:10px;max-height:48vh;overflow:auto;padding:3px 2px 12px}.chat-message{display:flex;align-items:flex-end;gap:7px;max-width:88%}.chat-message.mine{margin-left:auto;flex-direction:row-reverse}.chat-avatar{width:30px;height:30px;flex:0 0 30px;border:1.5px solid #171717;border-radius:50%;background:#ffe5d4;display:grid;place-items:center;font:900 10px Quicksand}.chat-bubble{border:2px solid #171717;border-radius:16px 16px 16px 5px;background:#fff;padding:8px 10px;min-width:0}.chat-message.mine .chat-bubble{border-radius:16px 16px 5px 16px;background:#e9e5ff}.chat-bubble strong{display:block;font:900 10px Nunito;margin-bottom:2px}.chat-bubble p{margin:0;font:700 12px/1.35 Quicksand;overflow-wrap:anywhere}.chat-bubble small{display:block;margin-top:4px;color:#888;font:700 9px Quicksand}.chat-composer{display:grid;grid-template-columns:minmax(0,1fr) 46px;gap:8px;margin-top:4px}.chat-composer input{height:46px!important;min-width:0}.chat-send{width:46px;height:46px;border:2px solid #171717;border-radius:15px;background:#171717;color:#fff;display:grid;place-items:center;box-shadow:-3px 4px 0 #a1a2a4}.chat-send:active{transform:translate(-1px,1px);box-shadow:-2px 2px 0 #a1a2a4}.rating-sheet{max-height:90vh}.sheet-note{margin:-8px 0 16px;color:#666;font:700 12px Quicksand}.rating-list{display:grid;gap:10px;margin-bottom:14px}.rating-row{border:2px solid #171717;border-radius:18px;background:#fff;padding:11px;display:grid;gap:9px}.rating-person{display:flex;align-items:center;gap:9px}.rating-person>span:last-child{display:grid;gap:2px}.rating-person strong{font:900 14px Nunito}.rating-person small{font:700 10px Quicksand;color:#777}.rating-score{display:grid;grid-template-columns:minmax(0,1fr) 46px 46px;align-items:center;gap:7px;min-width:0;isolation:isolate}.rating-stepper{position:relative;z-index:3;display:flex;align-items:center;justify-content:center;width:46px;min-width:46px;height:46px;border:1.5px solid #171717;border-radius:12px;background:#fff;color:#171717;font:900 22px/1 Nunito;box-shadow:-3px 4px 0 #a1a2a4;pointer-events:auto;touch-action:manipulation;user-select:none;-webkit-user-select:none;-webkit-touch-callout:none;-webkit-tap-highlight-color:transparent;padding:0}.rating-stepper:active{transform:translate(-1px,1px);box-shadow:-2px 2px 0 #a1a2a4}.stars{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:5px;width:100%;min-width:0;height:40px;border-radius:11px}.star-choice{width:100%;min-width:0;height:40px;border:1.5px solid #171717;border-radius:10px;background:#fff;color:#aaa;display:grid;place-items:center;user-select:none;pointer-events:none;-webkit-user-select:none}.star-choice{font-size:19px;line-height:1}.star-choice.filled{background:#ffe9bf;color:#171717}.star-choice.selected-star{box-shadow:-2px 2px 0 #a1a2a4}.rating-value{display:block;text-align:center;color:#777;font:800 10px Quicksand;white-space:nowrap;margin-top:-1px}.rating-toggles{display:grid;grid-template-columns:1fr 1fr;gap:7px}.rating-toggles button{border:1.5px solid #171717;border-radius:12px;background:#fff;padding:8px;font:800 10px Quicksand}.rating-toggles button.on{background:#ddf3e7}.profile-sport-grid{margin-bottom:10px}.profile-sport-grid button{border:2px solid #171717;border-radius:17px;background:#fff;padding:12px;display:flex;justify-content:space-between;align-items:center;font:900 12px Quicksand;box-shadow:-3px 4px 0 #ddd}.profile-sport-grid button.selected{background:#e9e5ff;box-shadow:-3px 4px 0 #a1a2a4}.profile-levels{margin-top:18px}.setting-card{border:2px solid #171717;border-radius:17px;background:#fff;padding:13px;display:flex;align-items:center;justify-content:space-between;gap:10px;margin-bottom:13px;box-shadow:-3px 4px 0 #ddd}.setting-card>span:first-child{display:grid;gap:3px}.setting-card strong{font:900 12px Nunito}.setting-card small{font:700 11px Quicksand;color:#777}.setting-value{font:800 10px Quicksand;background:#ddf3e7;border:1.5px solid #171717;border-radius:999px;padding:6px 8px}.toggle-row{width:100%;border:0;border-bottom:1px solid #ddd;background:#fff;padding:14px 0;display:flex;align-items:center;justify-content:space-between;gap:12px;text-align:left}.toggle-row>span:first-child{display:grid;gap:3px}.toggle-row strong{font:900 13px Nunito}.toggle-row small{font:700 10px/1.3 Quicksand;color:#777}.toggle{width:46px;height:27px;border:2px solid #171717;border-radius:99px;background:#eee;padding:3px;display:flex;align-items:center;justify-content:flex-start;flex:0 0 auto}.toggle span{width:17px;height:17px;border-radius:50%;background:#fff;border:1.5px solid #171717;box-shadow:-1px 2px 0 #aaa}.toggle.on{background:#dcecff;justify-content:flex-end}.toggle.on span{box-shadow:none}.scrim{position:fixed;inset:0;background:rgba(0,0,0,.38);z-index:10000;display:flex;align-items:flex-end}.scrim-backdrop{position:absolute;inset:0;width:100%;height:100%;border:0;background:transparent;padding:0;cursor:default}.sheet{position:relative;z-index:10001;width:min(430px,100%);margin:0 auto;background:#fbfbfb;border:2px solid #171717;border-bottom:0;border-radius:27px 27px 0 0;padding:20px 16px 120px;max-height:92vh;overflow:auto}.sheet h2{margin:0;font:900 25px Nunito}.sheet-head{margin-bottom:20px}.sheet .form-field{position:relative;z-index:2;display:grid;gap:6px;margin-bottom:13px}.sheet .form-field>.field-label{font:800 11px Quicksand}.sheet input,.sheet textarea{position:relative;z-index:3;pointer-events:auto;touch-action:auto;border:2px solid #171717;border-radius:14px;background:#fff;padding:0 12px;outline:0;font:700 13px Quicksand}.sheet input{height:45px}.sheet textarea{padding-top:11px;resize:vertical;min-height:75px}.two{display:grid;grid-template-columns:1fr 1fr;gap:10px}.picker-row{align-items:start}.picker-field{display:grid;gap:6px;min-width:0}.picker-label{font:800 11px Quicksand;display:block}.picker-button{position:relative;z-index:3;cursor:pointer;height:58px;width:100%;border:2px solid #171717;border-radius:16px;background:#fff;padding:8px 10px;display:flex;align-items:center;gap:8px;text-align:left;color:#171717;font:800 11px Quicksand;box-shadow:-3px 4px 0 #ddd;touch-action:manipulation;pointer-events:auto}.picker-button:active{transform:translate(-1px,1px);box-shadow:-2px 2px 0 #ddd}.picker-button-copy{display:grid;gap:2px;min-width:0;flex:1}.picker-button-copy strong{font:900 13px Nunito;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.picker-button-copy small{font:700 9px Quicksand;color:#888;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.picker-button.placeholder .picker-button-copy strong{color:#777}.picker-popover{margin:-4px 0 14px;border:2px solid #171717;border-radius:19px;background:#fff;box-shadow:-5px 6px 0 #a1a2a4;position:relative;z-index:2;overflow:hidden}.calendar-popover{padding:14px}.calendar-head{display:grid;grid-template-columns:38px 1fr 38px;align-items:center;gap:8px;text-align:center;margin-bottom:12px}.calendar-head strong{font:900 15px Nunito;text-transform:capitalize}.calendar-nav{width:36px;height:36px;border:1.5px solid #171717;border-radius:12px;background:#f8f8f8;display:grid;place-items:center}.weekdays,.calendar-grid{display:grid;grid-template-columns:repeat(7,1fr);gap:5px}.weekdays{margin-bottom:5px}.weekdays span{text-align:center;color:#888;font:800 10px Quicksand;padding:5px 0}.calendar-grid button,.calendar-grid span{height:36px}.calendar-grid button{border:1.5px solid transparent;border-radius:11px;background:#fff;font:800 12px Quicksand}.calendar-grid button:hover:not(:disabled){border-color:#171717;background:#f7f7f7}.calendar-grid button.selected{background:#dcecff;border-color:#171717;box-shadow:-2px 2px 0 #a1a2a4}.calendar-grid button:disabled{color:#c5c5c5;cursor:not-allowed}.time-popover{padding:14px}.time-wheel{height:220px;display:grid;grid-template-columns:1fr 1fr 1fr;gap:7px;position:relative;overflow:hidden}.wheel-column{height:220px;overflow-y:auto;scroll-snap-type:y mandatory;scrollbar-width:none;-ms-overflow-style:none;overscroll-behavior:contain}.wheel-column::-webkit-scrollbar{display:none}.wheel-column button{display:block;width:100%;height:44px;border:0;background:transparent;color:#777;font:800 26px/44px Quicksand;scroll-snap-align:center;opacity:.32}.wheel-column button.active-wheel{color:#171717;opacity:1;font-size:28px}.period-wheel button{font-size:25px}.wheel-spacer{height:88px;pointer-events:none}.wheel-selection{position:absolute;left:0;right:0;top:88px;height:44px;border-top:1.5px solid rgba(23,23,23,.2);border-bottom:1.5px solid rgba(23,23,23,.2);pointer-events:none}.wheel-fade{position:absolute;left:0;right:0;height:76px;z-index:2;pointer-events:none}.wheel-fade.top{top:0;background:linear-gradient(#fff,rgba(255,255,255,0))}.wheel-fade.bottom{bottom:0;background:linear-gradient(rgba(255,255,255,0),#fff)}.wheel-done{width:100%;margin-top:12px;border:2px solid #171717;border-radius:14px;background:#171717;color:#fff;height:43px;font:900 12px Quicksand}.toast{position:fixed;z-index:50;bottom:178px;left:50%;transform:translateX(-50%);background:#171717;color:#fff;border-radius:999px;padding:10px 15px;font:800 11px Quicksand;white-space:nowrap}@media(min-width:431px){.app-shell{margin-top:12px;min-height:calc(100vh - 24px);border-radius:5px}}

/* Unified selection + chat surface */
.selection-sheet{padding-top:20px}
.selector-field{position:relative;z-index:20}
.choice-button{position:relative;z-index:3;width:100%;min-height:60px;border:2px solid #171717;border-radius:17px;background:#fff;padding:10px 12px;display:flex;align-items:center;gap:10px;text-align:left;color:#171717;box-shadow:-3px 4px 0 #ddd;touch-action:manipulation;-webkit-tap-highlight-color:transparent}
.choice-button:active{transform:translate(-1px,1px);box-shadow:-2px 2px 0 #ddd}
.choice-button>span:first-child{display:grid;gap:3px;min-width:0;flex:1}
.choice-button strong{font:900 14px Nunito;line-height:1.1}
.choice-button small{font:700 10px/1.25 Quicksand;color:#888}
.choice-popover{margin:8px 0 2px;border:2px solid #171717;border-radius:19px;background:#fff;box-shadow:-5px 6px 0 #a1a2a4;position:relative;z-index:25;overflow:hidden}
.sport-popover{padding:10px}
.choice-grid{display:grid;grid-template-columns:1fr 1fr;gap:8px;max-height:360px;overflow:auto;padding:1px}
.choice-grid button{min-height:50px;border:1.5px solid #171717;border-radius:14px;background:#fbfbfb;padding:9px 10px;display:flex;align-items:center;justify-content:space-between;gap:7px;text-align:left;font:900 11px Nunito;box-shadow:-2px 3px 0 #e1e1e1;touch-action:manipulation;-webkit-tap-highlight-color:transparent}
.choice-grid button:active{transform:translate(-1px,1px);box-shadow:-1px 2px 0 #e1e1e1}
.choice-grid button.selected-choice{background:#e9e5ff;box-shadow:-2px 3px 0 #a1a2a4}
.choice-list{display:grid;gap:7px;padding:9px}
.choice-list button{min-height:60px;border:1.5px solid #171717;border-radius:15px;background:#fbfbfb;padding:9px 10px;display:grid;grid-template-columns:36px minmax(0,1fr) 20px;align-items:center;gap:9px;text-align:left;box-shadow:-2px 3px 0 #e1e1e1;touch-action:manipulation;-webkit-tap-highlight-color:transparent}
.choice-list button:active{transform:translate(-1px,1px);box-shadow:-1px 2px 0 #e1e1e1}
.choice-list button.selected-choice{background:#e9e5ff;box-shadow:-2px 3px 0 #a1a2a4}
.choice-option-icon{width:32px;height:32px;border:1.5px solid #171717;border-radius:11px;background:#fff;display:grid;place-items:center;font:900 12px Nunito}
.choice-list button.selected-choice .choice-option-icon{background:#171717;color:#fff}
.choice-option-copy{display:grid;gap:2px;min-width:0}
.choice-option-copy strong{font:900 13px Nunito;line-height:1.1}
.choice-option-copy small{font:700 9.5px/1.25 Quicksand;color:#777}
.choice-check{text-align:center;font:900 16px Nunito;min-width:20px}
.skill-popover{max-height:388px}
.visibility-popover{max-height:215px}
@media(max-width:370px){.choice-grid{gap:7px}.choice-grid button{padding-left:8px;padding-right:8px;font-size:10px}.choice-list button{grid-template-columns:32px minmax(0,1fr) 18px}.choice-option-icon{width:29px;height:29px}}
.selection-grid{display:grid;grid-template-columns:1fr 1fr;gap:9px}
.selection-grid button{min-height:48px}
.selection-section{margin-top:20px}
.profile-sport-grid{margin-bottom:0}
.profile-sport-grid button{min-height:50px}
.profile-sport-grid button span{width:22px;height:22px;border:1.5px solid #171717;border-radius:8px;display:grid;place-items:center;background:#fff;font:900 13px Nunito}
.profile-sport-grid button.selected span{background:#171717;color:#fff}
.chat-sheet{max-height:90vh}
.chat-detail-head{display:grid;grid-template-columns:42px minmax(0,1fr) 42px;align-items:center;gap:9px}
.chat-detail-head>div{text-align:center;min-width:0}
.chat-detail-head h2{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.chat-back{width:42px;height:42px}
.chat-selection-list{max-height:52vh;padding:4px 2px 14px;gap:11px}
.chat-selection-row{max-width:92%;align-items:flex-end}
.chat-selection-row .chat-bubble{box-shadow:-3px 4px 0 #ddd}
.chat-selection-row.mine .chat-bubble{box-shadow:-3px 4px 0 #a1a2a4}
.chat-selection-row .chat-avatar{box-shadow:-2px 3px 0 #ddd}
.chat-empty{border:2px solid #171717;border-radius:17px;background:#fff;padding:18px;text-align:center;box-shadow:-3px 4px 0 #ddd;color:#777;font:700 11px Quicksand}
.chat-event-row{border:2px solid #171717;border-radius:18px;background:#fff;box-shadow:-3px 4px 0 #ddd;padding:13px;display:grid;grid-template-columns:42px minmax(0,1fr) 18px;align-items:center;gap:10px;text-align:left;width:100%;margin-bottom:10px}
.chat-event-row:active{transform:translate(-1px,1px);box-shadow:-2px 2px 0 #ddd}
.chat-event-icon{width:42px;height:42px;border:1.5px solid #171717;border-radius:13px;background:#e9e5ff;display:grid;place-items:center}
.chat-event-copy{display:grid;gap:3px;min-width:0}
.chat-event-copy strong{font:900 13px Nunito;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.chat-event-copy small{font:700 10px Quicksand;color:#777}
.chat-composer{border-top:1.5px solid #ddd;padding-top:12px;margin-top:4px}

</style>
