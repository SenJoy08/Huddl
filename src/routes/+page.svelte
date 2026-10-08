<script>
  import EventCard from '$lib/components/EventCard.svelte';
  import { loadEventMessages, sendEventMessage } from '$lib/data/chat.js';
  import BottomNav from '$lib/components/BottomNav.svelte';
  import Icon from '$lib/components/Icon.svelte';
  import { loadGameCatalog } from '$lib/data/catalog.js';
  import { loadEsportsGames } from '$lib/data/esports.js';
  import { EMPTY_STATS, loadUserStats, loadPlayerStats } from '$lib/data/stats.js';
  import { getSession, signOut, onAuthStateChange } from '$lib/auth/session.js';
  import {
    DEFAULT_PROFILE,
    loadUserProfile,
    loadPublicProfile,
    saveProfileBasics,
    saveProfileSports,
    saveNotificationPreferences,
    saveAccountProfile
  } from '$lib/data/profile.js';
  import {
    loadSportEvents,
    loadUserEvents,
    createSportEvent,
    createEsportsEvent,
    joinPublicEvent,
    requestPrivateEvent,
    leaveEvent,
    updateSportEvent,
    updateEsportsEvent,
    setEventStatus,
    decideEventJoinRequest
  } from '$lib/data/events.js';
  import {
    loadFriends,
    sendFriendRequest as sendFriendRequestToDb,
    respondFriendRequest,
    removeFriend as removeFriendFromDb
  } from '$lib/data/friends.js';
  import { loadRatingPlayers, submitPlayerRating, markHostRatingsComplete } from '$lib/data/ratings.js';
  import {
    loadNotifications,
    markNotificationRead as markNotificationReadInDb,
    markAllNotificationsRead as markAllNotificationsReadInDb,
    subscribeToNotifications
  } from '$lib/data/notifications.js';
  import { subscribeToHuddlRealtime, subscribeToEventMessages } from '$lib/data/realtime.js';
  import { supabase } from '$lib/supabase/client.js';
  import { onDestroy, onMount } from 'svelte';
  import { fade, fly, scale, slide } from 'svelte/transition';
  import { goto } from '$app/navigation';

  /** @typedef {{ id: string, sport: string, title: string, startsAt?: string, date: string, dateValue?: string, time?: string, location: string, host: string, hostId?: string, members: number, capacity: number, skill: string, color: string, description: string, visibility?: string, status?: string, pendingRequests?: number, pendingRequestId?: string | null, isMember?: boolean, ratingsSubmitted?: boolean, eventType?: 'sport' | 'esports', platform?: string | null, gameMode?: string | null, gameId?: string, memberProfiles?: { id:string, name:string, handle:string, color:string }[] }} MockEvent */
  /** @typedef {{ games: number, hosted: number, rating: number|null, ratingCount: number, attendance: number|null, sports: { name: string, games: number }[] }} HuddlStats */
  /** @typedef {{ title: string, eventType: 'sport' | 'esports', sport: string, gameId: string, platform: string, gameMode: string, dateValue: string, time: string, location: string, capacity: number, skill: string, visibility: string, description: string }} EventForm */

  /** @param {unknown} error @param {string} fallback */
  function userFacingError(error, fallback) {
    const message = error instanceof Error ? error.message : String(error ?? '');
    const normalized = message.toLowerCase();

    if (normalized.includes('failed to fetch') || normalized.includes('network') || normalized.includes('fetch')) return 'Check your internet connection and try again.';
    if (normalized.includes('not authenticated') || normalized.includes('jwt') || normalized.includes('session')) return 'Your session has expired. Please log in again.';
    if (normalized.includes('duplicate') || normalized.includes('already exists') || normalized.includes('unique constraint')) return 'That already exists. Try a different value.';
    if (normalized.includes('permission') || normalized.includes('not allowed') || normalized.includes('forbidden')) return 'You do not have permission to do that.';
    if (normalized.includes('no longer joinable') || normalized.includes('event is full')) return 'This game is no longer available to join.';
    return fallback;
  }

  let active = 'home';
  /** @type {{ id: string, name: string, email: string } | null} */
  let session = null;
  let checkingAuth = true;
  /** @type {{ data: { subscription: { unsubscribe: () => void } } } | null} */
  let authSubscription = null;

  let filter = 'All';
  let eventSearch = '';
  let eventFilterOpen = false;
  let eventSortMode = 'recommended';
  let eventTimeFilter = 'all';
  let eventAvailabilityFilter = 'all';
  let eventSkillFilter = 'all';
  let homeSportsOpen = false;
  let homeEsportsOpen = false;
  /** @type {MockEvent[]} */
  let eventList = [];
  /** @type {MockEvent[]} */
  let userEventList = [];
  /** @type {MockEvent | null} */
  let selectedEvent = null;
  let hasSelectedEvent = false;
  let showCreate = false;
  let showEdit = false;
  let creatingEvent = false;
  let eventSaving = false;
  let eventAction = '';
  let friendAction = '';
  let eventsLoading = false;
  let eventsLoadError = '';
  let friendsLoading = false;
  let friendsLoadError = '';
  let statsLoadError = '';
  let notificationsLoadError = '';
  let chatLoadError = '';
  let ratingLoadError = '';
  let profileLoadError = '';
  let profileSaving = false;
  let sportsSaving = false;
  let settingsSaving = false;
  let accountSaving = false;
  let chatSending = false;
  let showNotifications = false;
  let showRating = false;
  let showChat = false;
  /** @type {MockEvent | null} */
  let chatEvent = null;
  let chatDraft = '';
  let chatLoading = false;
  /** @type {ReturnType<typeof setInterval> | null} */
  let chatPollTimer = null;
  /** IDs of games the current user has joined (or hosts). */
  let joinedEventIds = new Set();
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

  /** @typedef {{ id: string, name: string, handle: string, sports: string, status: string, color: string }} MockFriend */
  /** @typedef {{ id: string, name: string, handle: string, bio: string, sports: string[], skills: string[], phone?: string, color: string, stats: HuddlStats|null, relation?: string, status?: string }} PublicPlayerProfile */
  /** @typedef {{ name?: string, handle?: string, bio?: string, sports?: string|string[], skills?: string[], color?: string, relation?: string, status?: string }} PublicPlayerProfileFallback */
  /** @typedef {{ name: string, handle: string, bio: string, sports: string[], skills: string[], phone?: string, settings?: { showContact?: boolean, eventNotifications?: boolean, friendNotifications?: boolean, ratingNotifications?: boolean } }} MockProfile */
  /** @typedef {{ id: string, name: string, handle: string, sports: string, color: string, relation?: 'none' | 'friend' | 'incoming' | 'outgoing', requestId?: string }} FriendCandidate */
  /** @typedef {{ id: string, name: string, handle: string, sports: string, color: string, relation: 'none' | 'friend' | 'incoming' | 'outgoing', requestId?: string }} FriendSearchPerson */
  /** @typedef {{ id: string, name: string, handle: string, sports: string, color: string, senderId: string }} IncomingFriendRequest */
  /** @type {MockFriend[]} */
  let friendList = [];
  /** @type {FriendCandidate[]} */
  let friendCandidates = [];
  /** @type {FriendSearchPerson[]} */
  let peopleDirectory = [];
  /** @type {IncomingFriendRequest[]} */
  let incomingRequests = [];
  /** @type {PublicPlayerProfile | null} */
  let selectedPlayerProfile = null;
  let playerProfileLoading = false;
  /** @type {MockProfile} */
  let userProfile = { ...DEFAULT_PROFILE };
  /** @type {'profile' | 'sports' | 'account' | 'notifications' | 'events' | null} */
  let profileSheet = null;
  /** @type {'joined' | 'hosted'} */
  let eventsSegment = 'joined';
  /** @type {{ name: string, handle: string, bio: string }} */
  let profileDraft = { name: DEFAULT_PROFILE.name, handle: DEFAULT_PROFILE.handle, bio: DEFAULT_PROFILE.bio };
    /** @type {string[]} */
  let sportsDraft = [];
  /** @type {Record<string, string>} */
  let skillsDraft = {};
  let settingsDraft = { showContact: false, eventNotifications: true, friendNotifications: true, ratingNotifications: true };
  /** @type {HuddlStats} */
  let stats = { ...EMPTY_STATS, sports: [] };
  let statsLoading = false;
  /** @typedef {{ id: string, type: string, title: string, eventId?: string | null, friendRequestId?: string | null, message: string, time: string, createdAt: string, unread: boolean }} HuddlNotification */
  /** @type {HuddlNotification[]} */
  let notifications = [];
  let notificationsLoading = false;
  let passwordSheetOpen = false;
  let passwordDraft = { password: '', confirmPassword: '' };
  let passwordSaving = false;
  /** @type {(() => void) | null} */
  let notificationUnsubscribe = null;
  /** @type {(() => void) | null} */
  let realtimeUnsubscribe = null;
  /** @type {(() => void) | null} */
  let chatUnsubscribe = null;
  /** @type {(() => void) | null} */
  let visibilityCleanup = null;
  /** @type {ReturnType<typeof setTimeout> | null} */
  let liveRefreshTimer = null;
  let liveEventsQueued = false;
  let liveFriendsQueued = false;
  let liveRefreshRunning = false;
  /** @typedef {{ stars: number, showedUp: boolean, skillMatch: boolean, note: string }} RatingDraft */
  /** @typedef {{ id: string, name: string, role: string, stars: number, showedUp: boolean, skillMatch: boolean | null, note: string, canMarkAttendance: boolean }} RatingPlayer */
  /** @type {Record<string, RatingDraft>} */
  let ratingDrafts = {};
  /** @type {RatingPlayer[]} */
  let ratingPlayers = [];
  let ratingLoading = false;
  let sports = ['All'];
  /** @type {{ id: string, slug: string, name: string, platform?: string | null }[]} */
  let esportsGames = [];
  const DEFAULT_SKILL_LEVELS = ['Beginner', 'Amateur', 'Intermediate', 'Seasoned', 'Professional'];
  /** @type {string[]} */
  let skillLevels = [...DEFAULT_SKILL_LEVELS];
  let eventSportOpen = false;
  let eventGameOpen = false;
  let eventTypeOpen = false;
  let eventSkillOpen = false;
  let visibilityOpen = false;
  /** @typedef {{ id: string, senderId: string, sender: string, text: string, time: string, mine?: boolean }} ChatMessage */
  /** @type {Record<string, ChatMessage[]>} */
  let chatMessages = {};

  onMount(async () => {
    authSubscription = onAuthStateChange((event) => {
      if (event === 'SIGNED_OUT') {
        session = null;
        goto('/login');
      }
    });

    const authSession = await getSession();

    if (!authSession) {
      checkingAuth = false;
      goto('/login');
      return;
    }

    session = {
      id: authSession.user.id,
      name:
        authSession.user.user_metadata?.name ??
        authSession.user.email?.split('@')[0] ??
        'Player',
      email: authSession.user.email ?? ''
    };

    try {
      const dbProfile = await loadUserProfile(authSession.user.id);

      if (!dbProfile) {
        checkingAuth = false;
        goto('/onboarding');
        return;
      }

      userProfile = /** @type {MockProfile} */ (dbProfile);
      session = { ...session, name: dbProfile.name };
      const catalog = await loadGameCatalog();
      sports = Array.isArray(catalog?.sports) && catalog.sports.length ? catalog.sports : ['All'];
      const rawCatalogSkillLevels = /** @type {unknown} */ (catalog?.skillLevels);
      const catalogSkillLevels = Array.isArray(rawCatalogSkillLevels)
        ? rawCatalogSkillLevels
            .map((level) => {
              if (typeof level === 'string') return level;
              if (level && typeof level === 'object' && 'name' in level) {
                return typeof level.name === 'string' ? level.name : '';
              }
              return '';
            })
            .filter(Boolean)
        : [];
      skillLevels = catalogSkillLevels.length ? catalogSkillLevels : [...DEFAULT_SKILL_LEVELS];
      esportsGames = await loadEsportsGames();
      dateOptions = buildDateOptions();
      await refreshEvents(authSession.user.id);
      await refreshFriends(authSession.user.id);
      await refreshStats(authSession.user.id);

      try {
        notifications = await loadNotifications(authSession.user.id);
        notificationUnsubscribe = subscribeToNotifications(authSession.user.id, (notification) => {
          if (notification.unread) {
            notifications = [notification, ...notifications.filter((item) => item.id !== notification.id)].slice(0, 50);
          } else {
            notifications = notifications.filter((item) => item.id !== notification.id);
          }
        });
      } catch (notificationError) {
        console.error('Failed to load notifications:', notificationError);
      }

      realtimeUnsubscribe = subscribeToHuddlRealtime(authSession.user.id, {
        onEventsChange: () => queueLiveRefresh('events'),
        onFriendsChange: () => queueLiveRefresh('friends'),
        onStatus: (status) => {
          if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') {
            console.warn('Huddl realtime status:', status);
          }
        }
      });

      const refreshWhenVisible = () => {
        if (document.visibilityState === 'visible') {
          queueLiveRefresh('events');
          queueLiveRefresh('friends');
          void refreshNotifications();
        }
      };

      window.addEventListener('focus', refreshWhenVisible);
      document.addEventListener('visibilitychange', refreshWhenVisible);

      const cleanupVisibilityListeners = () => {
        window.removeEventListener('focus', refreshWhenVisible);
        document.removeEventListener('visibilitychange', refreshWhenVisible);
      };

      visibilityCleanup = cleanupVisibilityListeners;
    } catch (loadError) {
      console.error('Failed to load Huddl:', loadError);
      notice = loadError instanceof Error ? loadError.message : 'Could not load Huddl data';
    }

    if (!dateOptions.length) dateOptions = buildDateOptions();
    checkingAuth = false;
  });


  $: homeFilterIsEsports = filter === 'Esports' || filter.startsWith('esport:');
  $: eventSearchQuery = eventSearch.trim().toLowerCase();
  $: filteredEvents = (
    filter === 'All'
      ? eventList
      : filter === 'Esports'
        ? eventList.filter((event) => event.eventType === 'esports')
        : filter.startsWith('esport:')
          ? eventList.filter((event) => event.eventType === 'esports' && event.gameId === filter.slice(7))
          : eventList.filter((event) => event.eventType !== 'esports' && event.sport === filter)
  )
    .filter((event) => event.status === 'upcoming' || event.status === 'full')
    .filter((event) => {
      if (eventAvailabilityFilter === 'open') return event.members < event.capacity;
      if (eventAvailabilityFilter === 'full') return event.members >= event.capacity;
      return true;
    })
    .filter((event) => {
      if (eventSkillFilter === 'all') return true;
      return event.skill === eventSkillFilter;
    })
    .filter((event) => {
      if (eventTimeFilter === 'all') return true;
      if (!event.dateValue) return false;
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const eventDate = new Date(`${event.dateValue}T12:00:00`);
      if (eventTimeFilter === 'today') return eventDate.getTime() === today.getTime();
      if (eventTimeFilter === 'week') {
        const weekEnd = new Date(today);
        weekEnd.setDate(today.getDate() + 7);
        return eventDate >= today && eventDate < weekEnd;
      }
      if (eventTimeFilter === 'later') {
        const weekEnd = new Date(today);
        weekEnd.setDate(today.getDate() + 7);
        return eventDate >= weekEnd;
      }
      return true;
    })
    .filter((event) => eventSearchMatches(event, eventSearchQuery));
  $: activeEventFilterCount = [
    eventTimeFilter !== 'all',
    eventAvailabilityFilter !== 'all',
    eventSkillFilter !== 'all'
  ].filter(Boolean).length;
  $: discoveryEvents = [...filteredEvents].sort((a, b) => compareDiscoveryEvents(a, b));
  $: unreadNotifications = notifications.filter((item) => item.unread).length;
  $: searchQuery = search.trim().toLowerCase().replace(/^@+/, '');
  $: filteredFriends = friendList.filter((friend) => {
    if (!searchQuery) return true;
    return `${friend.name} ${friend.handle.replace(/^@+/, '')} ${friend.sports}`.toLowerCase().includes(searchQuery);
  });
  $: filteredCandidates = friendCandidates.filter((friend) => {
    if (!searchQuery) return true;
    return `${friend.name} ${friend.handle.replace(/^@+/, '')} ${friend.sports}`.toLowerCase().includes(searchQuery);
  });
  $: filteredPeople = peopleDirectory.filter((person) => {
    if (!searchQuery) return false;
    return `${person.name} ${person.handle.replace(/^@+/, '')} ${person.sports}`.toLowerCase().includes(searchQuery);
  });
  $: filteredIncomingRequests = incomingRequests.filter((request) => {
    if (!searchQuery) return true;
    return `${request.name} ${request.handle.replace(/^@+/, '')} ${request.sports}`.toLowerCase().includes(searchQuery);
  });
  $: displayedPeople = searchQuery ? filteredPeople : filteredCandidates;
  $: calendarDays = buildCalendarDays(calendarMonth);
  $: chatEvents = eventList.filter((event) => joinedEventIds.has(event.id) && event.status !== 'completed' && event.status !== 'cancelled');
  $: hasActiveChats = chatEvents.length > 0;
  $: visibleEvents = eventsSegment === 'hosted'
    ? userEventList.filter((event) => event.hostId === session?.id)
    : userEventList.filter((event) => event.isMember && event.hostId !== session?.id);
  $: sortedEvents = [...visibleEvents].sort((a, b) => {
    const rankA = a.status === 'cancelled' ? 2 : a.status === 'completed' ? 1 : 0;
    const rankB = b.status === 'cancelled' ? 2 : b.status === 'completed' ? 1 : 0;
    if (rankA !== rankB) return rankA - rankB;
    return `${a.dateValue ?? ''}T${a.time ?? ''}`.localeCompare(`${b.dateValue ?? ''}T${b.time ?? ''}`);
  });

  /** @param {string} eventHostId */
  function isEventHostById(eventHostId) {
    return Boolean(session?.id && eventHostId === session.id);
  }

  /** @param {string | undefined} [userId] */
  async function refreshEvents(userId = session?.id) {
    if (!userId) return;
    eventsLoading = true;
    eventsLoadError = '';

    const results = await Promise.allSettled([
      loadSportEvents(userId),
      loadUserEvents(userId)
    ]);

    const [discoveryResult, userResult] = results;
    const errors = [];

    if (discoveryResult.status === 'fulfilled') {
      eventList = discoveryResult.value;
    } else {
      console.error('Failed to load discovery events:', discoveryResult.reason);
      errors.push(discoveryResult.reason);
    }

    if (userResult.status === 'fulfilled') {
      userEventList = userResult.value;
    } else {
      console.error('Failed to load user events:', userResult.reason);
      errors.push(userResult.reason);
    }

    joinedEventIds = new Set(
      [...eventList, ...userEventList]
        .filter((event) => event.isMember || event.hostId === userId)
        .map((event) => event.id)
    );

    if (errors.length > 0) {
      eventsLoadError = userFacingError(errors[0], 'Could not load games right now.');
    }

    if (selectedEvent) {
      const refreshedSelected = [...eventList, ...userEventList].find((event) => event.id === selectedEvent?.id);
      selectedEvent = refreshedSelected ?? selectedEvent;
      if (!refreshedSelected) hasSelectedEvent = false;
    }

    eventsLoading = false;
  }

  async function refreshStats(userId = session?.id) {
    if (!userId) return;
    statsLoading = true;
    statsLoadError = '';
    try {
      stats = await loadUserStats(userId);
    } catch (statsError) {
      console.error('Failed to load stats:', statsError);
      statsLoadError = userFacingError(statsError, 'Could not load your stats right now.');
    } finally {
      statsLoading = false;
    }
  }

  async function refreshFriends(userId = session?.id) {
    if (!userId) return;
    friendsLoading = true;
    friendsLoadError = '';
    try {
      const friendData = await loadFriends(userId);
      friendList = friendData.friends;
      friendCandidates = friendData.candidates;
      peopleDirectory = friendData.people;
      incomingRequests = friendData.incomingRequests;
    } catch (friendsError) {
      console.error('Failed to load friends:', friendsError);
      friendsLoadError = userFacingError(friendsError, 'Could not load friends right now.');
    } finally {
      friendsLoading = false;
    }
  }

  /** @param {'events' | 'friends'} kind */
  function queueLiveRefresh(kind) {
    if (kind === 'events') liveEventsQueued = true;
    if (kind === 'friends') liveFriendsQueued = true;
    if (liveRefreshTimer !== null) return;

    liveRefreshTimer = setTimeout(async () => {
      liveRefreshTimer = null;
      if (liveRefreshRunning) return;

      liveRefreshRunning = true;
      const refreshEventsNow = liveEventsQueued;
      const refreshFriendsNow = liveFriendsQueued;
      liveEventsQueued = false;
      liveFriendsQueued = false;

      try {
        if (refreshEventsNow) await refreshEvents();
        if (refreshFriendsNow) await refreshFriends();
      } catch (liveError) {
        console.error('Live Huddl refresh failed:', liveError);
      } finally {
        liveRefreshRunning = false;
        if (liveEventsQueued || liveFriendsQueued) queueLiveRefresh(liveEventsQueued ? 'events' : 'friends');
      }
    }, 180);
  }


  /** @returns {EventForm} */
  function emptyEventForm() {
    return { title: '', eventType: 'sport', sport: 'Football', gameId: '', platform: '', gameMode: '', dateValue: '', time: '', location: '', capacity: 6, skill: 'Intermediate', visibility: 'Public', description: '' };
  }

  /** @param {EventForm} form @param {'sport' | 'esports'} eventType */
  function setEventType(form, eventType) {
    const next = {
      ...form,
      eventType,
      gameId: eventType === 'esports' ? form.gameId || esportsGames[0]?.id || '' : form.gameId,
      platform: eventType === 'sport' ? '' : form.platform,
      gameMode: eventType === 'sport' ? '' : form.gameMode,
    };

    if (form === editEvent) editEvent = next;
    else newEvent = next;

    eventSkillOpen = false;
    eventSportOpen = false;
    eventGameOpen = false;
    eventTypeOpen = false;
    visibilityOpen = false;
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
  /** @param {MockEvent} event @param {string} query */
  function eventSearchMatches(event, query) {
    if (!query) return true;
    const gameName = event.gameId
      ? esportsGames.find((game) => game.id === event.gameId)?.name ?? ''
      : '';
    const haystack = [
      event.title,
      event.description,
      event.location,
      event.host,
      event.sport,
      gameName
    ]
      .filter(Boolean)
      .join(' ')
      .toLowerCase();
    return haystack.includes(query);
  }

  /** @param {string} id */
  function navigate(id) {
    if (id !== 'home' && id !== 'friends' && id !== 'stats' && id !== 'profile') return;
    active = id;
    if (id === 'stats' && session?.id) void refreshStats(session.id);
    hasSelectedEvent = false;
    selectedEvent = null;
    selectedPlayerProfile = null;
    playerProfileLoading = false;
    showCreate = false;
    showEdit = false;
    calendarOpen = false;
    timeWheelOpen = false;
    eventSportOpen = false;
    eventGameOpen = false;
    eventTypeOpen = false;
    eventSkillOpen = false;
    visibilityOpen = false;
    showNotifications = false;
    showRating = false;
    ratingEvent = null;
    showChat = false;
    chatEvent = null;
    chatDraft = '';
    profileSheet = null;
    passwordSheetOpen = false;
    passwordDraft = { password: '', confirmPassword: '' };
    homeSportsOpen = false;
    homeEsportsOpen = false;
  }

  function clearEventFilters() {
    eventTimeFilter = 'all';
    eventAvailabilityFilter = 'all';
    eventSkillFilter = 'all';
  }

  /** @param {MockEvent} event */
  function eventStartTimestamp(event) {
    if (event.startsAt) {
      const timestamp = new Date(event.startsAt).getTime();
      if (!Number.isNaN(timestamp)) return timestamp;
    }
    if (!event.dateValue) return Number.MAX_SAFE_INTEGER;
    const [hours = '0', minutes = '0'] = String(event.time ?? '00:00').split(':');
    const date = new Date(`${event.dateValue}T${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:00`);
    const timestamp = date.getTime();
    return Number.isNaN(timestamp) ? Number.MAX_SAFE_INTEGER : timestamp;
  }

  /** @param {MockEvent} event */
  function eventRecommendationScore(event) {
    const eventSport = String(event.sport ?? '').trim().toLowerCase();
    const profileSports = Array.isArray(userProfile?.sports) ? userProfile.sports : [];
    const matchingSportIndex = profileSports.findIndex((sport) => String(sport).trim().toLowerCase() === eventSport);
    let score = 0;

    if (matchingSportIndex >= 0) {
      score += 100;
      const matchingSkill = userProfile?.skills?.[matchingSportIndex];
      if (matchingSkill && String(matchingSkill).toLowerCase() === String(event.skill ?? '').toLowerCase()) score += 35;
    }

    if (event.members < event.capacity) score += 15;

    const start = eventStartTimestamp(event);
    if (start !== Number.MAX_SAFE_INTEGER) {
      const hoursAway = Math.max(0, (start - Date.now()) / 3600000);
      score += Math.max(0, 12 - hoursAway / 24);
    }

    return score;
  }

  /** @param {MockEvent} a @param {MockEvent} b */
  function compareDiscoveryEvents(a, b) {
    if (eventSortMode === 'soonest') {
      const timeDiff = eventStartTimestamp(a) - eventStartTimestamp(b);
      if (timeDiff !== 0) return timeDiff;
      return (a.capacity - a.members) - (b.capacity - b.members);
    }

    const scoreDiff = eventRecommendationScore(b) - eventRecommendationScore(a);
    if (scoreDiff !== 0) return scoreDiff;
    return eventStartTimestamp(a) - eventStartTimestamp(b);
  }

  /** @param {MockEvent} event */
  function openEvent(event) {
    profileSheet = null;
    selectedEvent = event;
    hasSelectedEvent = true;
  }

  /** @param {string} nextFilter */
  function chooseHomeFilter(nextFilter) {
    filter = nextFilter;
    homeSportsOpen = false;
    homeEsportsOpen = false;
  }

  function toggleHomeSports() {
    homeSportsOpen = !homeSportsOpen;
    homeEsportsOpen = false;
  }

  function toggleHomeEsports() {
    homeEsportsOpen = !homeEsportsOpen;
    homeSportsOpen = false;
  }

  /** @param {'joined' | 'hosted'} segment */
  function openEventsSheet(segment = 'joined') {
    eventsSegment = segment;
    profileSheet = 'events';
  }

  function closeEvent() {
    hasSelectedEvent = false;
    selectedEvent = null;
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

  async function logout() {
    if (eventAction === 'logout') return;
    eventAction = 'logout';
    const { error } = await signOut();
    if (error) {
      notice = userFacingError(error, 'Could not save that change.');
      setTimeout(() => (notice = ''), 1800);
      eventAction = '';
      return;
    }
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


  function openChatHub() {
    showChat = true;
    chatEvent = null;
    chatDraft = '';
  }

  async function joinSelectedEvent() {
    if (eventAction || !selectedEvent || selectedEvent.status === 'cancelled' || selectedEvent.status === 'completed') return;
    if (eventStartTimestamp(selectedEvent) <= Date.now()) {
      notice = 'This event has already started';
      return;
    }
    if (selectedEvent.members >= selectedEvent.capacity) {
      notice = 'This game is full';
      return;
    }
    eventAction = 'join';
    try {
      if (selectedEvent.visibility === 'Private') {
        const result = await requestPrivateEvent(selectedEvent.id);
        notice = result === 'full'
          ? 'This game is full'
          : result === 'already_member'
            ? 'You are already in this game'
            : result === 'already_pending'
              ? 'Your join request is already pending'
              : 'Join request sent';
      } else {
        const result = await joinPublicEvent(selectedEvent.id);
        notice = result === 'full' ? 'This game is full' : result === 'already_member' ? 'You are already in this game' : 'You joined the game';
      }
      await refreshEvents();
    } catch (joinError) {
      notice = userFacingError(joinError, 'Could not join this game.');
    } finally {
      eventAction = '';
    }
    setTimeout(() => (notice = ''), 2200);
  }

  async function leaveSelectedEvent() {
    if (eventAction || !selectedEvent || isEventHostById(selectedEvent.hostId ?? '')) return;
    eventAction = 'leave';
    try {
      const result = await leaveEvent(selectedEvent.id);
      notice = result === 'not_member' ? 'You are not in this game' : 'You left the game';
      await refreshEvents();
    } catch (leaveError) {
      notice = userFacingError(leaveError, 'Could not leave this game.');
    } finally {
      eventAction = '';
    }
    setTimeout(() => (notice = ''), 2200);
  }

  function startCreate() {
    newEvent = emptyEventForm();
    newEvent.gameId = esportsGames[0]?.id ?? '';
    calendarOpen = false;
    timeWheelOpen = false;
    eventSportOpen = false;
    eventGameOpen = false;
    eventTypeOpen = false;
    eventSkillOpen = false;
    visibilityOpen = false;
    showCreate = true;
  }

  async function create() {
    if (creatingEvent) return;
    if (!newEvent.title || !newEvent.dateValue || !newEvent.time || !newEvent.location || Number(newEvent.capacity) < 2) {
      notice = 'Fill in all required fields';
      return;
    }
    if (newEvent.eventType === 'esports' && !newEvent.gameId) {
      notice = 'Choose an esports game';
      return;
    }

    creatingEvent = true;

    try {
      const eventId = newEvent.eventType === 'esports'
        ? await createEsportsEvent(newEvent)
        : await createSportEvent(newEvent);
      showCreate = false;
      newEvent = emptyEventForm();
      active = 'home';
      filter = 'All';
      eventSearch = '';
      eventTimeFilter = 'all';
      eventAvailabilityFilter = 'all';
      eventSkillFilter = 'all';
      await refreshEvents();
      notice = eventId ? 'Event created' : 'Event created';
    } catch (createError) {
      notice = userFacingError(createError, 'Could not create this game.');
    } finally {
      creatingEvent = false;
    }
    setTimeout(() => (notice = ''), 2200);
  }

  /** @param {MockEvent | null} event */
  function startEdit(event) {
    if (!event) return;
    const [datePart, timePart] = event.date.split(', ');
    const option = dateOptions.find((item) => item.label === datePart);
    editEvent = {
      title: event.title,
      eventType: event.eventType ?? 'sport',
      sport: event.eventType === 'sport' ? event.sport : 'Football',
      gameId: event.gameId ?? '',
      platform: event.platform ?? '',
      gameMode: event.gameMode ?? '',
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
    eventSportOpen = false;
    eventGameOpen = false;
    eventTypeOpen = false;
    eventSkillOpen = false;
    visibilityOpen = false;
    showEdit = true;
  }

  async function saveEdit() {
    if (eventSaving) return;
    if (!selectedEvent || !editEvent.title || !editEvent.dateValue || !editEvent.time || !editEvent.location) {
      notice = 'Fill in all required fields';
      return;
    }
    editEvent = { ...editEvent, capacity: Math.max(Number(editEvent.capacity), selectedEvent.members) };
    eventSaving = true;
    try {
      if (selectedEvent.eventType === 'esports') await updateEsportsEvent(selectedEvent.id, editEvent);
      else await updateSportEvent(selectedEvent.id, editEvent);
      await refreshEvents();
      showEdit = false;
      notice = 'Event updated';
    } catch (updateError) {
      notice = userFacingError(updateError, 'Could not update this game.');
    } finally {
      eventSaving = false;
    }
    setTimeout(() => (notice = ''), 2200);
  }

  async function cancelSelectedEvent() {
    if (eventAction || !selectedEvent || !isEventHostById(selectedEvent.hostId ?? '')) return;
    eventAction = 'cancel';
    try {
      await setEventStatus(selectedEvent.id, 'cancelled');
      await refreshEvents();
      hasSelectedEvent = false;
      notice = 'Event cancelled';
    } catch (cancelError) {
      notice = userFacingError(cancelError, 'Could not cancel this game.');
    } finally {
      eventAction = '';
    }
    setTimeout(() => (notice = ''), 2200);
  }

  async function finishSelectedEvent() {
    if (eventAction || !selectedEvent || !isEventHostById(selectedEvent.hostId ?? '')) return;
    eventAction = 'finish';
    const eventBeforeFinish = selectedEvent;
    try {
      await setEventStatus(selectedEvent.id, 'completed');
      await refreshEvents();
      await refreshStats();
      hasSelectedEvent = false;
      const ratingOpened = await openRating(eventBeforeFinish);
      if (!ratingOpened) return;
      notice = 'Event marked complete';
    } catch (finishError) {
      notice = userFacingError(finishError, 'Could not finish this game.');
    } finally {
      eventAction = '';
    }
    setTimeout(() => (notice = ''), 2200);
  }

  async function acceptRequest() {
    if (eventAction || !selectedEvent || !selectedEvent.pendingRequests || !selectedEvent.pendingRequestId) return;
    eventAction = 'accept-request';
    try {
      await decideEventJoinRequest(selectedEvent.pendingRequestId, true);
      await refreshEvents();
      notice = 'Request accepted';
    } catch (acceptError) {
      notice = userFacingError(acceptError, 'Could not accept the request.');
    } finally {
      eventAction = '';
    }
    setTimeout(() => (notice = ''), 2200);
  }

  async function rejectRequest() {
    if (eventAction || !selectedEvent || !selectedEvent.pendingRequests || !selectedEvent.pendingRequestId) return;
    eventAction = 'reject-request';
    try {
      await decideEventJoinRequest(selectedEvent.pendingRequestId, false);
      await refreshEvents();
      notice = 'Request declined';
    } catch (rejectError) {
      notice = userFacingError(rejectError, 'Could not decline the request.');
    } finally {
      eventAction = '';
    }
    setTimeout(() => (notice = ''), 2200);
  }

  async function openPendingRequestProfile() {
    const requestId = selectedEvent?.pendingRequestId;
    if (!requestId) return;

    try {
      const { data, error } = await supabase
        .from('event_join_requests')
        .select('user_id')
        .eq('id', requestId)
        .maybeSingle();

      if (error) throw error;
      if (!data?.user_id) throw new Error('This join request is no longer available.');

      await openPlayerProfile(data.user_id);
    } catch (requestError) {
      notice = userFacingError(requestError, 'Could not open the requester profile.');
      setTimeout(() => (notice = ''), 2200);
    }
  }

  /** @param {MockEvent} event */
  async function openRating(event) {
    if (event.ratingsSubmitted || !session || event.hostId !== session.id) return false;

    ratingEvent = event;
    ratingPlayers = [];
    ratingDrafts = {};
    ratingLoadError = '';
    ratingLoading = true;
    showRating = true;

    try {
      const players = await loadRatingPlayers(event.id, session.id);

      if (!players.length) {
        await markHostRatingsComplete(event.id);
        const completedEvent = { ...event, ratingsSubmitted: true };
        eventList = eventList.map((item) => item.id === event.id ? completedEvent : item);
        if (selectedEvent?.id === event.id) selectedEvent = completedEvent;
        showRating = false;
        ratingEvent = null;
        notice = 'Ratings complete';
        setTimeout(() => (notice = ''), 1800);
        return false;
      }

      ratingPlayers = players;
      /** @type {Record<string, RatingDraft>} */
      const drafts = {};

      for (const player of players) {
        drafts[player.id] = {
          stars: player.stars,
          showedUp: player.canMarkAttendance ? player.showedUp : true,
          skillMatch: player.skillMatch ?? true,
          note: player.note
        };
      }

      ratingDrafts = drafts;
    } catch (ratingError) {
      ratingLoadError = userFacingError(ratingError, 'Could not load players to rate right now.');
      notice = ratingLoadError;
      setTimeout(() => (notice = ''), 2200);
    } finally {
      ratingLoading = false;
    }

    return ratingEvent !== null;
  }

  /** @param {MockEvent} event */
  /**
   * Normalize chat messages for the initials-only avatar UI.
   * @param {ChatMessage[]} messages
   * @returns {Promise<ChatMessage[]>}
   */
  async function hydrateChatAvatars(messages) {
    return (messages ?? []).map((message) => ({
      ...message,
      senderId: message.senderId ?? ''
    }));
  }

  /** @param {MockEvent} event */
  async function openChat(event) {
    if (!isChatAvailable(event) || !session) return;

    chatUnsubscribe?.();
    chatUnsubscribe = null;
    if (chatPollTimer !== null) {
      clearInterval(chatPollTimer);
      chatPollTimer = null;
    }

    chatEvent = event;
    showChat = true;
    chatDraft = '';
    chatLoading = true;
    chatLoadError = '';

    const eventId = String(event.id);
    const userId = session.id;

    // Subscribe first so no message can arrive in the gap between the initial
    // database read and establishing the realtime subscription.
    chatUnsubscribe = subscribeToEventMessages(
      eventId,
      async (payload) => {
        if (!session || String(payload.new?.event_id ?? '') !== eventId) return;
        try {
          const freshMessages = await loadEventMessages(eventId, session.id);
          chatMessages = { ...chatMessages, [eventId]: await hydrateChatAvatars(freshMessages) };
        } catch (messageError) {
          console.error('Live chat refresh failed:', messageError);
        }
      },
      (status) => {
        if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') {
          console.warn('Huddl chat realtime status:', status);
        }
      }
    );

    try {
      const messages = await loadEventMessages(eventId, userId);
      chatMessages = { ...chatMessages, [eventId]: await hydrateChatAvatars(messages) };

      // Realtime remains the primary path. This low-frequency fallback only
      // runs while the chat sheet is open, so an interrupted websocket cannot
      // leave the other player's chat permanently stale.
      chatPollTimer = setInterval(async () => {
        if (!chatEvent || !session || String(chatEvent.id) !== eventId) return;
        try {
          const freshMessages = await loadEventMessages(eventId, session.id);
          chatMessages = { ...chatMessages, [eventId]: await hydrateChatAvatars(freshMessages) };
        } catch (messageError) {
          console.error('Chat fallback refresh failed:', messageError);
        }
      }, 2500);
    } catch (messageError) {
      console.error('Failed to load chat:', messageError);
      chatLoadError = userFacingError(messageError, 'Could not load this chat right now.');
      notice = chatLoadError;
    } finally {
      chatLoading = false;
    }
  }

  async function retryChat() {
    if (!chatEvent || !session || chatLoading) return;
    await openChat(chatEvent);
  }

  function closeChat() {
    chatUnsubscribe?.();
    chatUnsubscribe = null;
    if (chatPollTimer !== null) {
      clearInterval(chatPollTimer);
      chatPollTimer = null;
    }
    showChat = false;
    chatEvent = null;
    chatDraft = '';
    chatLoading = false;
    chatLoadError = '';
  }

  async function sendChatMessage() {
    if (chatSending || !chatEvent || !session || !chatDraft.trim()) return;
    const eventId = String(chatEvent.id);
    const text = chatDraft.trim();
    chatDraft = '';
    chatSending = true;
    try {
      await sendEventMessage(eventId, text);
      const messages = await loadEventMessages(eventId, session.id);
      chatMessages = { ...chatMessages, [eventId]: await hydrateChatAvatars(messages) };
    } catch (messageError) {
      chatDraft = text;
      notice = userFacingError(messageError, 'Could not send the message.');
      setTimeout(() => (notice = ''), 2200);
    } finally {
      chatSending = false;
    }
  }

  function openSelectedEventRating() {
    if (!selectedEvent || !session || selectedEvent.hostId !== session.id) return;
    openRating(selectedEvent);
  }

  /** @param {string} playerId @param {number} stars */
  function setPlayerRating(playerId, stars) {
    const nextStars = Math.trunc(Number(stars));
    if (!Number.isFinite(nextStars) || nextStars < 1 || nextStars > 5) return;
    const current = ratingDrafts[playerId] ?? { stars: 0, showedUp: true, skillMatch: true, note: '' };
    ratingDrafts = {
      ...ratingDrafts,
      [playerId]: { ...current, stars: nextStars }
    };
  }


  /** @param {string} playerId @param {'showedUp' | 'skillMatch'} field */
  function toggleRatingField(playerId, field) {
    const player = ratingPlayers.find((item) => item.id === playerId);
    if (field === 'showedUp' && !player?.canMarkAttendance) return;
    const current = ratingDrafts[playerId] ?? { stars: 0, showedUp: true, skillMatch: true, note: '' };
    const nextValue = !current[field];
    ratingDrafts = {
      ...ratingDrafts,
      [playerId]: { ...current, [field]: nextValue, ...(field === 'showedUp' && !nextValue ? { stars: 0, skillMatch: false } : {}) }
    };
  }

  async function submitRatings() {
    if (!ratingEvent || !session || ratingLoading) return;

    const players = ratingPlayers.map((player) => ({
      player,
      draft: ratingDrafts[player.id] ?? { stars: 0, showedUp: true, skillMatch: true, note: '' }
    }));

    if (!players.length) {
      notice = 'There are no other players to rate';
      setTimeout(() => (notice = ''), 1800);
      return;
    }

    const missingRatings = players.filter((item) => item.draft.showedUp && item.draft.stars < 1).length;
    if (missingRatings > 0) {
      notice = `Rate the ${missingRatings} player${missingRatings === 1 ? '' : 's'} who showed up`;
      setTimeout(() => (notice = ''), 1800);
      return;
    }

    ratingLoading = true;

    try {
      for (const item of players) {
        await submitPlayerRating({
          eventId: ratingEvent.id,
          playerId: item.player.id,
          stars: item.draft.stars,
          showedUp: item.draft.showedUp,
          skillMatch: item.draft.showedUp ? item.draft.skillMatch : null,
          note: item.draft.note
        });
      }

      await markHostRatingsComplete(ratingEvent.id);
      const ratedEvent = { ...ratingEvent, ratingsSubmitted: true };
      ratingEvent = ratedEvent;
      eventList = eventList.map((event) => event.id === ratedEvent.id ? ratedEvent : event);
      if (selectedEvent?.id === ratedEvent.id) selectedEvent = ratedEvent;
      showRating = false;
      ratingEvent = null;
      ratingPlayers = [];
      ratingDrafts = {};
      await refreshStats();
      notice = 'Ratings submitted';
    } catch (ratingError) {
      notice = userFacingError(ratingError, 'Could not submit ratings.');
    } finally {
      ratingLoading = false;
    }

    setTimeout(() => (notice = ''), 2200);
  }

  async function refreshNotifications() {
    if (!session) return;
    notificationsLoading = true;
    notificationsLoadError = '';
    try {
      notifications = await loadNotifications(session.id);
    } catch (notificationError) {
      console.error('Failed to refresh notifications:', notificationError);
      notificationsLoadError = userFacingError(notificationError, 'Could not load notifications right now.');
    } finally {
      notificationsLoading = false;
    }
  }

  async function openNotifications() {
    showNotifications = true;
    showRating = false;
    await refreshNotifications();
  }

  /** @param {HuddlNotification} item */
  async function handleNotificationClick(item) {
    await markNotificationRead(item.id);

    const linkedEvent = item.eventId
      ? eventList.find((event) => event.id === item.eventId)
      : null;

    showNotifications = false;

    if (linkedEvent) {
      openEvent(linkedEvent);
      return;
    }

    if (item.type.startsWith('friend_')) {
      active = 'friends';
    }
  }

  /** @param {string} id */
  async function markNotificationRead(id) {
    const previous = notifications;
    notifications = notifications.filter((item) => item.id !== id);

    try {
      await markNotificationReadInDb(id);
    } catch (notificationError) {
      console.error('Failed to mark notification read:', notificationError);
      notifications = previous;
      notice = userFacingError(notificationError, 'Could not update the notification.');
      setTimeout(() => (notice = ''), 1800);
    }
  }

  async function markAllNotificationsRead() {
    const previous = notifications;
    notifications = [];

    try {
      await markAllNotificationsReadInDb();
    } catch (notificationError) {
      console.error('Failed to mark all notifications read:', notificationError);
      notifications = previous;
      notice = userFacingError(notificationError, 'Could not update notifications.');
      setTimeout(() => (notice = ''), 1800);
    }
  }

  onDestroy(() => {
    authSubscription?.data?.subscription?.unsubscribe?.();
    authSubscription = null;
    notificationUnsubscribe?.();
    notificationUnsubscribe = null;
    realtimeUnsubscribe?.();
    realtimeUnsubscribe = null;
    chatUnsubscribe?.();
    chatUnsubscribe = null;
    if (chatPollTimer !== null) {
      clearInterval(chatPollTimer);
      chatPollTimer = null;
    }
    visibilityCleanup?.();
    visibilityCleanup = null;
    if (liveRefreshTimer !== null) {
      clearTimeout(liveRefreshTimer);
      liveRefreshTimer = null;
    }
  });

  /** @param {FriendCandidate} candidate */
  async function sendFriendRequest(candidate) {
    const key = `send:${candidate.id}`;
    if (friendAction === key) return;
    friendAction = key;
    let result;
    try {
      result = await sendFriendRequestToDb(candidate.id);
    } catch (requestError) {
      console.error('Send friend request failed:', requestError);
      notice = userFacingError(requestError, 'Could not send the friend request.');
      friendAction = '';
      setTimeout(() => (notice = ''), 2200);
      return;
    }
    if (result === 'incoming_pending') notice = `${candidate.name} already sent you a request`;
    else if (result === 'already_friend') notice = `You are already friends with ${candidate.name}`;
    else if (result === 'already_pending') notice = `Request already sent to ${candidate.name}`;
    else if (result === 'sent') notice = `Request sent to ${candidate.name}`;
    else notice = `Request status: ${result}`;
    if (session) {
      try {
        await refreshFriends(session.id);
      } catch (refreshError) {
        console.error('Friend list refresh failed after request:', refreshError);
      }
    }
    friendAction = '';
    setTimeout(() => (notice = ''), 2200);
  }

  /** @param {FriendCandidate} candidate */
  async function acceptSearchResult(candidate) {
    const requestId = candidate.requestId;
    if (!requestId) return;

    await acceptFriendRequest({
      id: requestId,
      name: candidate.name,
      handle: candidate.handle,
      sports: candidate.sports,
      color: candidate.color,
      senderId: candidate.id
    });
  }

  /** @param {IncomingFriendRequest} request */
  async function acceptFriendRequest(request) {
    const key = `accept:${request.id}`;
    if (friendAction === key) return;
    friendAction = key;
    try {
      await respondFriendRequest(request.id, true);
      if (session) await refreshFriends(session.id);
      notice = `${request.name} is now your friend`;
    } catch (requestError) {
      notice = userFacingError(requestError, 'Could not accept the friend request.');
    } finally {
      friendAction = '';
    }
    setTimeout(() => (notice = ''), 2200);
  }

  /** @param {IncomingFriendRequest} request */
  async function declineFriendRequest(request) {
    const key = `decline:${request.id}`;
    if (friendAction === key) return;
    friendAction = key;
    try {
      await respondFriendRequest(request.id, false);
      if (session) await refreshFriends(session.id);
      notice = 'Request declined';
    } catch (requestError) {
      notice = userFacingError(requestError, 'Could not decline the friend request.');
    } finally {
      friendAction = '';
    }
    setTimeout(() => (notice = ''), 2200);
  }

  /** @param {MockFriend} friend */
  async function removeFriend(friend) {
    const key = `remove:${friend.id}`;
    if (friendAction === key) return;
    friendAction = key;
    try {
      await removeFriendFromDb(friend.id);
      if (session) await refreshFriends(session.id);
      selectedPlayerProfile = null;
      playerProfileLoading = false;
      notice = `${friend.name} removed from friends`;
    } catch (removeError) {
      notice = userFacingError(removeError, 'Could not remove this friend.');
    } finally {
      friendAction = '';
    }
    setTimeout(() => (notice = ''), 2200);
  }

  /** @param {string} id */
  function avatarColorForId(id) {
    const colors = ['blue', 'peach', 'lavender', 'mint'];
    let hash = 0;
    for (let index = 0; index < id.length; index += 1) hash = (hash * 31 + id.charCodeAt(index)) | 0;
    return colors[Math.abs(hash) % colors.length];
  }

  function retrySelectedPlayerProfile() {
    const profile = selectedPlayerProfile;
    if (!profile) return;
    openPlayerProfile(profile.id, profile);
  }

  /**
   * @param {string} playerId
   * @param {PublicPlayerProfileFallback} [fallback]
   */
  async function openPlayerProfile(playerId, fallback = {}) {
    if (!playerId) return;

    if (playerId === session?.id) {
      selectedPlayerProfile = null;
      playerProfileLoading = false;
      active = 'profile';
      hasSelectedEvent = false;
      selectedEvent = null;
      showChat = false;
      showRating = false;
      return;
    }

    selectedPlayerProfile = {
      id: playerId,
      name: fallback.name ?? 'Player',
      handle: fallback.handle ?? '@player',
      bio: fallback.bio ?? 'Always down for a game.',
      sports: Array.isArray(fallback.sports) ? fallback.sports : String(fallback.sports ?? '').split(' · ').filter(Boolean),
      skills: Array.isArray(fallback.skills) ? fallback.skills : [],
      color: fallback.color ?? avatarColorForId(playerId),
      stats: null,
      phone: '',
      relation: fallback.relation,
      status: fallback.status
    };
    playerProfileLoading = true;
    profileLoadError = '';

    try {
      const [profile, playerStats] = await Promise.all([
        loadPublicProfile(playerId),
        loadPlayerStats(playerId)
      ]);

      if (!profile) throw new Error('This player profile is unavailable.');
      selectedPlayerProfile = {
        ...selectedPlayerProfile,
        ...profile,
        color: fallback.color ?? avatarColorForId(playerId),
        stats: playerStats
      };
    } catch (profileError) {
      profileLoadError = userFacingError(profileError, 'Could not load this player profile right now.');
      notice = profileLoadError;
      setTimeout(() => (notice = ''), 2200);
    } finally {
      playerProfileLoading = false;
    }
  }

  function closePlayerProfile() {
    selectedPlayerProfile = null;
    playerProfileLoading = false;
    profileLoadError = '';
  }

  function openProfileEditor() {
    profileDraft = { name: userProfile.name, handle: userProfile.handle, bio: userProfile.bio };
    profileSheet = 'profile';
  }


  async function saveProfileEditor() {
    if (profileSaving) return;
    profileSaving = true;
    if (!session) { profileSaving = false; return; }

    const name = profileDraft.name.trim();
    const handle = profileDraft.handle.trim().startsWith('@')
      ? profileDraft.handle.trim()
      : `@${profileDraft.handle.trim()}`;

    if (!name || !handle.slice(1)) {
      notice = 'Name and handle are required';
      setTimeout(() => (notice = ''), 1800);
      profileSaving = false;
      return;
    }

    const bio = profileDraft.bio.trim() || 'Always down for a game.';
    const { error } = await saveProfileBasics(session.id, { name, handle, bio });

    if (error) {
      notice = userFacingError(error, 'Could not save that change.');
      setTimeout(() => (notice = ''), 2200);
      profileSaving = false;
      return;
    }

    userProfile = { ...userProfile, name, handle, bio };
    session = { ...session, name };
    profileSheet = null;
    profileSaving = false;
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

  async function saveSportsEditor() {
    if (sportsSaving) return;
    sportsSaving = true;
    if (!session) { sportsSaving = false; return; }

    if (!sportsDraft.length) {
      notice = 'Choose at least one sport';
      setTimeout(() => (notice = ''), 1800);
      sportsSaving = false;
      return;
    }

    const { error } = await saveProfileSports(session.id, sportsDraft, skillsDraft);

    if (error) {
      notice = userFacingError(error, 'Could not save that change.');
      setTimeout(() => (notice = ''), 2200);
      sportsSaving = false;
      return;
    }

    userProfile = {
      ...userProfile,
      sports: sportsDraft,
      skills: sportsDraft.map((sport) => skillsDraft[sport] ?? 'Intermediate')
    };
    profileSheet = null;
    sportsSaving = false;
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

  async function saveSettings() {
    if (settingsSaving) return;
    settingsSaving = true;
    if (!session) { settingsSaving = false; return; }

    const { error } = await saveNotificationPreferences(session.id, {
      eventNotifications: settingsDraft.eventNotifications,
      friendNotifications: settingsDraft.friendNotifications,
      ratingNotifications: settingsDraft.ratingNotifications
    });

    if (error) {
      notice = userFacingError(error, 'Could not save that change.');
      setTimeout(() => (notice = ''), 2200);
      settingsSaving = false;
      return;
    }

    const contactError = await saveAccountProfile(session.id, {
      contactVisible: settingsDraft.showContact
    });

    if (contactError) {
      notice = userFacingError(contactError, 'Could not save your account settings.');
      setTimeout(() => (notice = ''), 2200);
      settingsSaving = false;
      return;
    }

    userProfile = { ...userProfile, settings: { ...settingsDraft } };
    profileSheet = null;
    settingsSaving = false;
    notice = 'Settings saved';
    setTimeout(() => (notice = ''), 1800);
  }

  function openPasswordSheet() {
    passwordDraft = { password: '', confirmPassword: '' };
    passwordSheetOpen = true;
    profileSheet = null;
  }

  function closePasswordSheet() {
    if (passwordSaving) return;
    passwordSheetOpen = false;
    passwordDraft = { password: '', confirmPassword: '' };
  }

  async function changePassword() {
    if (!session || passwordSaving) return;

    const password = passwordDraft.password;
    const confirmPassword = passwordDraft.confirmPassword;

    if (password.length < 6) {
      notice = 'Password must be at least 6 characters';
      setTimeout(() => (notice = ''), 2200);
      return;
    }

    if (password !== confirmPassword) {
      notice = 'Passwords do not match';
      setTimeout(() => (notice = ''), 2200);
      return;
    }

    passwordSaving = true;
    try {
      const { error } = await supabase.auth.updateUser({ password });
      if (error) throw error;
      passwordSheetOpen = false;
      passwordDraft = { password: '', confirmPassword: '' };
      notice = 'Password updated';
    } catch (passwordError) {
      notice = userFacingError(passwordError, 'Could not update your password.');
    } finally {
      passwordSaving = false;
    }
    setTimeout(() => (notice = ''), 2200);
  }

  async function saveAccountSettings() {
    if (accountSaving) return;
    accountSaving = true;
    if (!session) { accountSaving = false; return; }

    const contactVisible = userProfile.settings?.showContact ?? false;
    const error = await saveAccountProfile(session.id, {
      phone: userProfile.phone ?? '',
      contactVisible
    });

    if (error) {
      notice = userFacingError(error, 'Could not save that change.');
      setTimeout(() => (notice = ''), 2200);
      accountSaving = false;
      return;
    }

    profileSheet = null;
    accountSaving = false;
    notice = 'Account saved';
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
  {#if selectedEvent}
    <main class="screen detail-screen" transition:fly={{ y: 18, duration: 240, opacity: 0.98 }}>
      <button class="back" aria-label="Back" onclick={closeEvent}><Icon name="back" size={23}/></button>
      <div class="detail-hero {selectedEvent.color} {selectedEvent.eventType === 'esports' ? 'esports' : ''}">
        <div class="hero-row">
          <div class="hero-tags"><span class="pill">{selectedEvent.sport}</span><span class="skill-tag">{selectedEvent.skill}</span></div>
          <span class="status-pill {selectedEvent.status ?? 'upcoming'}">{selectedEvent.status === 'full' ? 'Full' : selectedEvent.status === 'completed' ? 'Completed' : selectedEvent.status === 'cancelled' ? 'Cancelled' : selectedEvent.visibility ?? 'Public'}</span>
        </div>
        <div class="hero-copy"><h1>{selectedEvent.title}</h1>{#if selectedEvent.description}<p>{selectedEvent.description}</p>{/if}</div>
      </div>
      <div class="detail-grid">
        <div><Icon name="calendar" size={19}/><span>{selectedEvent.date}</span></div>
        <div><Icon name="map" size={19}/><span>{selectedEvent.location}</span></div>
        {#if selectedEvent.eventType === 'esports'}
          {#if selectedEvent.platform}<div><Icon name="monitor" size={19}/><span>{selectedEvent.platform}</span></div>{/if}
          {#if selectedEvent.gameMode}<div><Icon name="gamepad" size={19}/><span>{selectedEvent.gameMode}</span></div>{/if}
        {/if}
      </div>
      <section class="panel players-panel">
        <div class="panel-head"><div><h2>Players</h2><span class="panel-subtitle">Who's in the game</span></div><strong>{selectedEvent?.members ?? 0}/{selectedEvent?.capacity ?? 0}</strong></div>
        <div class="big-progress"><span style={`width:${Math.round(((selectedEvent?.members ?? 0) / Math.max(selectedEvent?.capacity ?? 1, 1)) * 100)}%`}></span></div>
        <div class="player-count-line"><span>{Math.max((selectedEvent?.capacity ?? 0) - (selectedEvent?.members ?? 0), 0)} spots left</span><span>{Math.round(((selectedEvent?.members ?? 0) / Math.max(selectedEvent?.capacity ?? 1, 1)) * 100)}% filled</span></div>
        <div class="avatars">{#each selectedEvent.memberProfiles ?? [] as player}<button type="button" class="profile-avatar-chip {avatarColorForId(player.id)}" aria-label={`Open ${player.name}'s profile`} onclick={() => openPlayerProfile(player.id, player)}>{player.name[0]?.toUpperCase() ?? '?'}</button>{/each}{#if (selectedEvent?.memberProfiles?.length ?? 0) < (selectedEvent?.members ?? 0)}<span class="empty">+</span>{/if}</div>
      </section>
      <div class="host-line"><span>Hosted by</span><button type="button" class="profile-link" onclick={() => openPlayerProfile(selectedEvent?.hostId ?? '', { name: selectedEvent?.host })}>{selectedEvent?.host ?? ''}</button></div>

      {#if isEventHostById(selectedEvent.hostId ?? '')}
        <section class="host-actions">
          {#if selectedEvent.status === 'completed'}
            {#if !selectedEvent.ratingsSubmitted}<button class="primary" onclick={openSelectedEventRating}>Rate players</button>{/if}
          {:else if selectedEvent.status === 'upcoming' || selectedEvent.status === 'full'}
            <button class="secondary" disabled={Boolean(eventAction)} onclick={() => startEdit(selectedEvent)}><Icon name="edit" size={17}/>Edit event</button>
            <button class="secondary" disabled={Boolean(eventAction)} onclick={finishSelectedEvent}><Icon name="check" size={17}/>{eventAction === 'finish' ? 'Finishing…' : 'Finish event'}</button>
            <button class="danger" disabled={Boolean(eventAction)} onclick={cancelSelectedEvent}><Icon name="close" size={17}/>{eventAction === 'cancel' ? 'Cancelling…' : 'Cancel event'}</button>
          {/if}
          {#if (selectedEvent.pendingRequests ?? 0) > 0}
            <div class="request-box">
              <button type="button" class="request-summary" onclick={openPendingRequestProfile} aria-label="View requester profile">
                <span class="request-summary-icon"><Icon name="user" size={18}/></span>
                <span class="request-summary-copy">
                  <strong>{selectedEvent.pendingRequests} join request{selectedEvent.pendingRequests === 1 ? '' : 's'}</strong>
                  <span>Tap to view the requester profile.</span>
                </span>
                <Icon name="chevron" size={17}/>
              </button>
              <div class="request-actions"><button class="accept" disabled={Boolean(eventAction)} onclick={acceptRequest}>{eventAction === 'accept-request' ? 'Accepting…' : 'Accept'}</button><button class="decline" disabled={Boolean(eventAction)} onclick={rejectRequest}>{eventAction === 'reject-request' ? 'Declining…' : 'Decline'}</button></div>
            </div>
          {/if}
        </section>
      {:else if selectedEvent.status === 'completed'}
        <div class="state-message">This event is completed.</div>
      {:else if selectedEvent.status === 'cancelled'}
        <div class="state-message">This event is cancelled.</div>
      {:else if selectedEvent.isMember}
        <div class="state-message">You are in this game.</div>
        <div class="join-actions"><button class="secondary" disabled={Boolean(eventAction)} onclick={leaveSelectedEvent}>{eventAction === 'leave' ? 'Leaving…' : 'Leave game'}</button></div>
      {:else if selectedEvent.visibility === 'Private' && (selectedEvent.pendingRequests ?? 0) > 0}
        <div class="state-message">Your join request is pending.</div>
      {:else if selectedEvent.members >= selectedEvent.capacity}
        <div class="state-message">This game is full.</div>
      {:else if eventStartTimestamp(selectedEvent) <= Date.now()}
        <div class="state-message">This event has already started.</div>
      {:else}
        <div class="join-actions"><button class="primary" disabled={Boolean(eventAction)} onclick={joinSelectedEvent}>{eventAction === 'join' ? (selectedEvent.visibility === 'Private' ? 'Sending request…' : 'Joining…') : selectedEvent.visibility === 'Private' ? 'Request to join' : 'Join game'}</button></div>
      {/if}
    </main>
  {:else if active === 'home'}
    <main class="screen" transition:fade={{ duration: 170 }}>
      <header class="toolbar"><div><p class="eyebrow">HUDDL</p><h1>Find your next game.</h1></div><div class="toolbar-actions"><button class="notification-button" aria-label="Notifications" onclick={openNotifications}><Icon name="bell" size={21}/>{#if unreadNotifications > 0}<span class="notification-dot">{unreadNotifications}</span>{/if}</button><button class="avatar {avatarColorForId(session?.id ?? userProfile.name)}" aria-label="Profile" onclick={() => navigate('profile')}>{session?.name?.[0]?.toUpperCase() ?? 'S'}</button></div></header>
      <div class="filters home-filters">
        <button class:chosen={filter === 'All'} onclick={() => chooseHomeFilter('All')}>All</button>
        <button class="esports-filter-button" class:chosen={homeFilterIsEsports && filter === 'Esports'} onclick={toggleHomeEsports}>Esports <span aria-hidden="true">⌄</span></button>
        <button class="sports-filter-button" class:chosen={filter !== 'All' && !homeFilterIsEsports} onclick={toggleHomeSports}>Sports <span aria-hidden="true">⌄</span></button>
      </div>
      {#if homeSportsOpen}
        <div class="home-filter-popover home-sports-popover" transition:slide={{ duration: 170 }}>
          {#each sports.slice(1) as sport (sport)}
            <button class="home-filter-option sports-option" class:selected-choice={filter === sport} onclick={() => chooseHomeFilter(sport)}>{sport}<span class="choice-check">{filter === sport ? '✓' : ''}</span></button>
          {/each}
        </div>
      {:else if homeEsportsOpen}
        <div class="home-filter-popover home-esports-popover" transition:slide={{ duration: 170 }}>
          <button class="home-filter-option esports-option" class:selected-choice={filter === 'Esports'} onclick={() => chooseHomeFilter('Esports')}>All Esports<span class="choice-check">{filter === 'Esports' ? '✓' : ''}</span></button>
          {#if esportsGames.length === 0}
            <div class="home-filter-empty">No esports games available.</div>
          {:else}
            {#each esportsGames as game (game.id)}
              <button class="home-filter-option esports-option" class:selected-choice={filter === `esport:${game.id}`} onclick={() => chooseHomeFilter(`esport:${game.id}`)}>{game.name}<span class="choice-check">{filter === `esport:${game.id}` ? '✓' : ''}</span></button>
            {/each}
          {/if}
        </div>
      {/if}
      <div class="event-discovery-tools">
        <div class="event-search">
          <Icon name="search" size={19}/>
          <input bind:value={eventSearch} aria-label="Search games" placeholder="Search games, sports or locations" onpointerup={focusFormControl} ontouchend={focusFormControl} />
          {#if eventSearch}
            <button type="button" class="event-search-clear" aria-label="Clear game search" onclick={() => eventSearch = ''}><Icon name="close" size={16}/></button>
          {/if}
        </div>
        <button type="button" class="event-filter-button" class:active={eventFilterOpen || activeEventFilterCount > 0} aria-expanded={eventFilterOpen} aria-label="Filter games" onclick={() => eventFilterOpen = !eventFilterOpen}>
          <Icon name="filter" size={18}/><span>Filter</span>{#if activeEventFilterCount > 0}<b>{activeEventFilterCount}</b>{/if}
        </button>
      </div>
      {#if eventFilterOpen}
        <div class="event-filter-popover" transition:slide={{ duration: 170 }}>
          <div class="event-filter-head"><div><strong>Refine games</strong><small>Choose only what you want to see.</small></div>{#if activeEventFilterCount > 0}<button type="button" class="tiny" onclick={clearEventFilters}>Clear</button>{/if}</div>
          <div class="event-filter-section"><span>When</span><div class="event-filter-chips">
            <button type="button" class:chosen={eventTimeFilter === 'all'} onclick={() => eventTimeFilter = 'all'}>Any time</button>
            <button type="button" class:chosen={eventTimeFilter === 'today'} onclick={() => eventTimeFilter = 'today'}>Today</button>
            <button type="button" class:chosen={eventTimeFilter === 'week'} onclick={() => eventTimeFilter = 'week'}>Next 7 days</button>
            <button type="button" class:chosen={eventTimeFilter === 'later'} onclick={() => eventTimeFilter = 'later'}>Later</button>
          </div></div>
          <div class="event-filter-section"><span>Availability</span><div class="event-filter-chips">
            <button type="button" class:chosen={eventAvailabilityFilter === 'open'} onclick={() => eventAvailabilityFilter = 'open'}>Open spots</button>
            <button type="button" class:chosen={eventAvailabilityFilter === 'all'} onclick={() => eventAvailabilityFilter = 'all'}>Any</button>
            <button type="button" class:chosen={eventAvailabilityFilter === 'full'} onclick={() => eventAvailabilityFilter = 'full'}>Full</button>
          </div></div>
          <div class="event-filter-section"><span>Skill</span><div class="event-filter-chips">
            <button type="button" class:chosen={eventSkillFilter === 'all'} onclick={() => eventSkillFilter = 'all'}>Any skill</button>
            {#each skillLevels as level (level)}<button type="button" class:chosen={eventSkillFilter === level} onclick={() => eventSkillFilter = level}>{level}</button>{/each}
          </div></div>
        </div>
      {/if}
      {#if eventsLoadError && discoveryEvents.length === 0}
        <div class="state-message load-state error-state">
          <strong>Couldn’t load games</strong>
          <span>Check your connection and try again.</span>
          <button type="button" class="tiny" disabled={eventsLoading} onclick={() => refreshEvents()}>{eventsLoading ? 'Retrying…' : 'Try again'}</button>
        </div>
      {:else if eventsLoading && eventList.length === 0}
        <div class="discovery-skeleton-list" aria-label="Loading games">
          {#each [1, 2, 3] as item (item)}
            <div class="event-skeleton">
              <span class="skeleton-line wide"></span>
              <span class="skeleton-line medium"></span>
              <span class="skeleton-line short"></span>
              <div class="skeleton-footer"><span class="skeleton-pill"></span><span class="skeleton-pill small"></span></div>
            </div>
          {/each}
        </div>
      {/if}
      <section>
        <div class="section-head discovery-head">
          <div><h2>{eventSearchQuery ? 'Search results' : 'Upcoming'}</h2><span>{discoveryEvents.length} {discoveryEvents.length === 1 ? 'game' : 'games'}</span></div>
          <div class="discovery-sort" role="group" aria-label="Sort games">
            <button type="button" class:chosen={eventSortMode === 'recommended'} onclick={() => eventSortMode = 'recommended'}>For you</button>
            <button type="button" class:chosen={eventSortMode === 'soonest'} onclick={() => eventSortMode = 'soonest'}>Soonest</button>
          </div>
        </div>
        {#if discoveryEvents.length === 0}
          <div class="state-message home-empty-state">
            <strong>{eventSearchQuery ? 'No games found' : homeFilterIsEsports ? 'No esports games right now' : filter !== 'All' ? `No ${filter} games right now` : 'No games right now'}</strong>
            <span>{eventSearchQuery ? 'Try a different game, sport, host or location.' : 'Check back soon or create a game for others to join.'}</span>
            {#if eventSearchQuery}<button type="button" class="tiny" onclick={() => eventSearch = ''}>Clear search</button>{/if}
          </div>
        {:else}
          <div class="feed">
            {#each discoveryEvents as event (event.id)}
              <div class="event-discovery-item" transition:fly={{ y: 10, duration: 180, opacity: 0.2 }}>
                <EventCard {event} onOpen={() => openEvent(event)} onHostClick={() => openPlayerProfile(event.hostId ?? '', { name: event.host })}/>
              </div>
            {/each}
          </div>
        {/if}
      </section>
    </main>
  {:else if active === 'friends'}
    <main class="screen" transition:fade={{ duration: 170 }}><header class="page-head"><div><p class="eyebrow">COMMUNITY</p><h1>Friends</h1></div><button class="avatar {avatarColorForId(session?.id ?? userProfile.name)}" aria-label="Profile" onclick={() => navigate('profile')}>{session?.name?.[0]?.toUpperCase() ?? 'S'}</button></header>
      <div class="search"><Icon name="search" size={19}/><input bind:value={search} placeholder="Search people" onpointerup={focusFormControl} ontouchend={focusFormControl} /></div>
      {#if friendsLoadError && friendList.length === 0 && friendCandidates.length === 0 && incomingRequests.length === 0}
        <div class="state-message load-state error-state">
          <strong>Couldn’t load friends</strong>
          <span>Check your connection and try again.</span>
          <button type="button" class="tiny" disabled={friendsLoading} onclick={() => refreshFriends()}>{friendsLoading ? 'Retrying…' : 'Try again'}</button>
        </div>
      {:else if friendsLoading && friendList.length === 0 && friendCandidates.length === 0 && incomingRequests.length === 0}
        <div class="friend-skeleton-list" aria-label="Loading friends">
          {#each [1, 2, 3, 4] as item (item)}
            <div class="friend-skeleton"><span class="skeleton-avatar"></span><span class="skeleton-copy"><span class="skeleton-line medium"></span><span class="skeleton-line short"></span></span><span class="skeleton-action"></span></div>
          {/each}
        </div>
      {/if}
      {#if filteredIncomingRequests.length > 0}
        <section class="panel compact-panel"><div class="panel-head"><h2>Friend requests</h2><span class="request-count">{filteredIncomingRequests.length} waiting</span></div>{#each filteredIncomingRequests as request}<div class="request-row"><button type="button" class="request-person" onclick={() => openPlayerProfile(request.senderId, request)}><span class="friend-avatar {avatarColorForId(request.senderId)}">{(request.name?.[0] ?? request.handle?.replace(/^@+/, '')?.[0] ?? '?').toUpperCase()}</span><span class="friend-copy"><strong>{request.name}</strong><small>{request.handle} · {request.sports}</small></span></button><button class="request-action accept" disabled={friendAction === `accept:${request.id}`} onclick={() => acceptFriendRequest(request)}>{friendAction === `accept:${request.id}` ? 'Accepting…' : 'Accept'}</button><button class="request-action decline" disabled={friendAction === `decline:${request.id}`} onclick={() => declineFriendRequest(request)}>{friendAction === `decline:${request.id}` ? 'Declining…' : 'Decline'}</button></div>{/each}</section>
      {/if}
      <section class="friends-section"><div class="section-head"><h2>{searchQuery ? 'Search results' : 'Find people'}</h2><span>{displayedPeople.length} results</span></div><div class="list">{#each displayedPeople as candidate}<div class="friend-row"><button class="friend-main" onclick={() => openPlayerProfile(candidate.id, candidate)}><span class="friend-avatar {avatarColorForId(candidate.id)}">{(candidate.name?.[0] ?? candidate.handle?.replace(/^@+/, '')?.[0] ?? '?').toUpperCase()}</span><span class="friend-copy"><strong>{candidate.name}</strong><small>{candidate.handle} · {candidate.sports}</small></span></button>{#if searchQuery}{#if candidate.relation === 'none'}<button class="tiny" disabled={friendAction === `send:${candidate.id}`} onclick={() => sendFriendRequest(candidate)}>{friendAction === `send:${candidate.id}` ? 'Sending…' : 'Add'}</button>{:else if candidate.relation === 'outgoing'}<button class="tiny" disabled>Pending</button>{:else if candidate.relation === 'incoming' && candidate.requestId}<button class="tiny" disabled={friendAction === `accept:${candidate.requestId}`} onclick={() => acceptSearchResult(candidate)}>{friendAction === `accept:${candidate.requestId}` ? 'Accepting…' : 'Accept'}</button>{:else}<button class="tiny" disabled>Friends</button>{/if}{:else}<button class="tiny" disabled={friendAction === `send:${candidate.id}`} onclick={() => sendFriendRequest(candidate)}>{friendAction === `send:${candidate.id}` ? 'Sending…' : 'Add'}</button>{/if}</div>{/each}</div></section>
      <section class="friends-section"><div class="section-head"><h2>Your friends</h2><span>{filteredFriends.length} friends</span></div><div class="list">{#each filteredFriends as friend}<div class="friend-row"><button class="friend-main" onclick={() => openPlayerProfile(friend.id, friend)}><span class="friend-avatar {avatarColorForId(friend.id)}">{(friend.name?.[0] ?? friend.handle?.replace(/^@+/, '')?.[0] ?? '?').toUpperCase()}</span><span class="friend-copy"><strong>{friend.name}</strong><small>{friend.handle} · {friend.sports}</small></span><span class="status">{friend.status}</span></button><button class="tiny" disabled={friendAction === `remove:${friend.id}`} onclick={() => removeFriend(friend)}>{friendAction === `remove:${friend.id}` ? 'Removing…' : 'Remove'}</button></div>{/each}</div></section>
    </main>
  {:else if active === 'stats'}
    <main class="screen" transition:fade={{ duration: 170 }}>
      <header class="page-head"><div><p class="eyebrow">YOUR PLAY</p><h1>Stats</h1></div></header>
      {#if statsLoadError && stats.games === 0}
        <div class="state-message load-state error-state">
          <strong>Couldn’t load your stats</strong>
          <span>{statsLoadError}</span>
          <button type="button" class="tiny" disabled={statsLoading} onclick={() => refreshStats()}>{statsLoading ? 'Retrying…' : 'Try again'}</button>
        </div>
      {:else if statsLoading && stats.games === 0}
        <div class="state-message load-state"><strong>Loading your stats…</strong><span>Pulling your completed games and ratings.</span></div>
      {:else}
        <section class="stats-hero">
          <div class="stats-hero-top">
            <div>
              <p class="eyebrow">HUDDL SCORECARD</p>
              <strong>{stats.rating === null ? '—' : stats.rating.toFixed(1)}</strong>
              <span>Average rating · {stats.ratingCount} ratings</span>
            </div>
            <div class="stats-hero-badge">
              <Icon name="star" size={19}/>
              <span>{stats.games} {stats.games === 1 ? 'game' : 'games'}</span>
            </div>
          </div>
          <div class="stats-hero-meta">
            <div><strong>{stats.hosted}</strong><span>Hosted</span></div>
            <div><strong>{stats.attendance === null ? '—' : `${stats.attendance}%`}</strong><span>Attendance</span></div>
          </div>
        </section>
        <section class="panel stats-sport-panel">
          <div class="panel-head"><div><h2>Games by sport / game</h2><span class="panel-subtitle">Your completed play</span></div><strong>{stats.sports.length}</strong></div>
          {#if stats.sports.length === 0}
            <div class="state-message">No completed games yet.</div>
          {:else}
            {@const maxSportGames = Math.max(...stats.sports.map((sport) => sport.games), 1)}
            <div class="stats-bars">
              {#each stats.sports as sport}
                <div class="bar-row">
                  <div><span>{sport.name}</span><strong>{sport.games}</strong></div>
                  <div class="bar"><span style={`width:${Math.max(8, Math.round((sport.games / maxSportGames) * 100))}%`}></span></div>
                </div>
              {/each}
            </div>
          {/if}
        </section>
        {#if stats.attendance === null && stats.games > 0}
          <p class="sheet-note">Attendance will appear once completed games have recorded attendance.</p>
        {/if}
      {/if}
    </main>
  {:else}
    <main class="screen profile-screen" transition:fade={{ duration: 170 }}>
      <section class="profile-hero">
        <div class="profile-hero-top">
          <span class="profile-avatar {avatarColorForId(session?.id ?? userProfile.name)}">{userProfile.name?.[0]?.toUpperCase() ?? 'P'}</span>
          <button class="round" aria-label="Edit profile" onclick={openProfileEditor}><Icon name="edit" size={19}/></button>
        </div>
        <div class="profile-identity">
          <p class="eyebrow">YOUR HUDDL</p>
          <h1>{userProfile.name}</h1>
          <p class="profile-handle">{userProfile.handle}</p>
        </div>
        {#if userProfile.bio}
          <p class="bio">{userProfile.bio}</p>
        {/if}
      </section>

      <section class="panel profile-sports-panel">
        <div class="panel-head">
          <div class="profile-section-title"><h2>Your sports</h2><span>{userProfile.sports.length} selected</span></div>
          <button class="tiny" onclick={openSportsEditor}>Edit</button>
        </div>
        {#if userProfile.sports.length === 0}
          <div class="state-message profile-inline-state">No sports selected yet.</div>
        {:else}
          <div class="profile-sports-list">
            {#each userProfile.sports as sport,i}
              <div class="sport-row">
                <span>{sport}</span>
                <span class="sport-level">{userProfile.skills[i]}</span>
              </div>
            {/each}
          </div>
        {/if}
      </section>

      <section class="profile-settings-block">
        <p class="profile-settings-label">QUICK ACCESS</p>
        <div class="settings profile-settings">
          <button onclick={() => openEventsSheet('joined')}>
            <span class="setting-leading"><span class="setting-icon calendar"><Icon name="calendar" size={17}/></span><span><strong>Your events</strong><small>Hosted and joined games</small></span></span>
            <Icon name="chevron" size={18}/>
          </button>
          <button onclick={openAccountSettings}>
            <span class="setting-leading"><span class="setting-icon account"><Icon name="user" size={17}/></span><span><strong>Account settings</strong><small>Profile and password</small></span></span>
            <Icon name="chevron" size={18}/>
          </button>
          <button onclick={openNotificationSettings}>
            <span class="setting-leading"><span class="setting-icon preferences"><Icon name="settings" size={17}/></span><span><strong>Preferences</strong><small>Choose what Huddl can notify you about</small></span></span>
            <Icon name="chevron" size={18}/>
          </button>
          <button onclick={openNotifications}>
            <span class="setting-leading"><span class="setting-icon notifications"><Icon name="bell" size={17}/></span><span><strong>Notifications</strong><small>{unreadNotifications > 0 ? unreadNotifications + ' unread update' + (unreadNotifications === 1 ? '' : 's') : "You're all caught up"}</small></span></span>
            {#if unreadNotifications > 0}<span class="setting-badge">{unreadNotifications}</span>{:else}<Icon name="chevron" size={18}/>{/if}
          </button>
        </div>
      </section>

      <button class="profile-signout" disabled={eventAction === 'logout'} onclick={logout}>
        <span><strong>{eventAction === 'logout' ? 'Signing out…' : 'Sign out'}</strong><small>End this Huddl session</small></span>
        <Icon name="chevron" size={18}/>
      </button>
    </main>
  {/if}

  {#if !hasSelectedEvent && hasActiveChats}
    <button class="chat-fab" transition:scale={{ duration: 180, start: 0.82 }} aria-label="Open game chats" onclick={openChatHub}><Icon name="message" size={25}/></button>
  {/if}
  {#if !hasSelectedEvent}<button class="create" transition:scale={{ duration: 180, start: 0.82 }} aria-label="Create event" onclick={startCreate}><Icon name="plus" size={29} stroke={3}/></button>{/if}

  <BottomNav {active} onNavigate={navigate}/>

  {#if showNotifications}
    <div class="scrim" transition:fade={{ duration: 190 }}>
      <button class="scrim-backdrop" type="button" aria-label="Close notifications" onclick={() => showNotifications = false}></button>
      <section class="sheet notification-sheet" aria-label="Notifications" transition:fly={{ y: 34, duration: 260, opacity: 0.98 }}>
        <div class="sheet-head"><div><p class="eyebrow">UPDATES</p><h2>Notifications</h2></div><button class="round" aria-label="Close" onclick={() => showNotifications = false}><Icon name="close" size={20}/></button></div>
        {#if notificationsLoadError && notifications.length === 0}
          <div class="state-message load-state error-state">
            <strong>Couldn’t load notifications</strong>
            <span>{notificationsLoadError}</span>
            <button type="button" class="tiny" disabled={notificationsLoading} onclick={() => refreshNotifications()}>{notificationsLoading ? 'Retrying…' : 'Try again'}</button>
          </div>
        {:else if notificationsLoading}
          <div class="state-message load-state"><strong>Loading notifications…</strong><span>Checking for new updates.</span></div>
        {:else if notifications.length === 0}
          <div class="state-message">You're all caught up.</div>
        {:else}
          <div class="notification-list">
            {#each notifications as item (item.id)}
              <button type="button" class:unread={item.unread} class="notification-row" onclick={() => handleNotificationClick(item)}>
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
    <div class="scrim" transition:fade={{ duration: 190 }}>
      <button class="scrim-backdrop" type="button" aria-label="Close game chats" onclick={closeChat}></button>
      <section class="sheet chat-sheet selection-sheet" aria-label="Game chats" transition:fly={{ y: 34, duration: 260, opacity: 0.98 }}>
        {#if chatEvent}
          <div class="chat-surface-inner" transition:slide={{ duration: 180 }}>
          <div class="sheet-head chat-detail-head"><button class="back chat-back" aria-label="Back to chats" onclick={() => { chatUnsubscribe?.(); chatUnsubscribe = null; if (chatPollTimer !== null) { clearInterval(chatPollTimer); chatPollTimer = null; } chatEvent = null; chatDraft = ''; chatLoading = false; }}><Icon name="back" size={20}/></button><div><p class="eyebrow">GAME CHAT</p><h2>{chatEvent.title}</h2></div><button class="round" aria-label="Close" onclick={closeChat}><Icon name="close" size={20}/></button></div>
          <div class="chat-meta"><span>{chatEvent.members} players</span><span>Game group</span></div>
          <div class="chat-list chat-selection-list">
            {#if chatLoadError}
              <div class="state-message load-state error-state">
                <strong>Couldn’t load this chat</strong>
                <span>{chatLoadError}</span>
                <button type="button" class="tiny" disabled={chatLoading} onclick={retryChat}>{chatLoading ? 'Retrying…' : 'Try again'}</button>
              </div>
            {:else if chatLoading}
              <div class="chat-empty">Loading messages…</div>
            {:else if (chatMessages[String(chatEvent.id)] ?? []).length === 0}
              <div class="chat-empty">No messages yet. Start the conversation.</div>
            {:else}
              {#each chatMessages[String(chatEvent.id)] ?? [] as message (message.id)}
                <div class="chat-message chat-selection-row {message.mine ? 'mine' : ''}">
                  <button type="button" class="chat-avatar-button" aria-label={`Open ${message.sender}'s profile`} onclick={() => openPlayerProfile(message.senderId, { name: message.sender })}><span class="chat-avatar {avatarColorForId(message.senderId)}">{message.sender[0]?.toUpperCase() ?? '?'}</span></button>
                  <div class="chat-bubble"><button type="button" class="profile-link chat-sender-link" onclick={() => openPlayerProfile(message.senderId, { name: message.sender })}>{message.mine ? 'You' : message.sender}</button><p>{message.text}</p><small>{message.time}</small></div>
                </div>
              {/each}
            {/if}
          </div>
          {#if !chatLoadError}<form class="chat-composer" onsubmit={(event) => { event.preventDefault(); sendChatMessage(); }}>
            <input bind:value={chatDraft} aria-label="Message" placeholder="Message the group…" onpointerup={focusFormControl} ontouchend={focusFormControl} />
            <button type="submit" class="chat-send" aria-label="Send message" disabled={chatSending || !chatDraft.trim()}><Icon name="send" size={18}/></button>
          </form>{/if}
          </div>
        {:else}
          <div class="chat-surface-inner" transition:slide={{ duration: 180 }}>
          <div class="sheet-head"><div><p class="eyebrow">HUDDL CHATS</p><h2>Your game chats</h2></div><button class="round" aria-label="Close" onclick={closeChat}><Icon name="close" size={20}/></button></div>
          <div class="chat-hub-list">
            {#each chatEvents as event (event.id)}
              <button class="chat-event-row" type="button" onclick={() => openChat(event)}>
                <span class="chat-event-icon"><Icon name="message" size={20}/></span>
                <span class="chat-event-copy"><strong>{event.title}</strong><small>{event.eventType === 'esports' ? `Esports · ${event.sport}` : event.sport} · {event.date}</small></span>
                <Icon name="chevron" size={18}/>
              </button>
            {/each}
          </div>
          </div>
        {/if}
      </section>
    </div>
  {/if}

  {#if showRating && ratingEvent}
    <div class="scrim" transition:fade={{ duration: 190 }}>
      <button class="scrim-backdrop" type="button" aria-label="Close rating" onclick={() => showRating = false}></button>
      <section class="sheet rating-sheet" aria-label="Rate players" transition:fly={{ y: 34, duration: 260, opacity: 0.98 }}>
        <div class="sheet-head"><div><p class="eyebrow">POST-GAME</p><h2>Rate players</h2></div><button class="round" aria-label="Close" onclick={() => showRating = false}><Icon name="close" size={20}/></button></div>
        <div class="rating-summary">
          <div class="rating-summary-copy">
            <strong>How did everyone do?</strong>
            <span>{ratingEvent.title}</span>
          </div>
          {#if ratingPlayers.length > 0}
            <span class="rating-progress">{ratingPlayers.filter((player) => (ratingDrafts[player.id]?.stars ?? 0) > 0).length}/{ratingPlayers.length} rated</span>
          {/if}
        </div>
        {#if ratingPlayers.some((player) => player.canMarkAttendance)}
          <div class="rating-host-note"><Icon name="check" size={15}/><span>As the host, you can also mark attendance.</span></div>
        {/if}
        {#if ratingLoadError && ratingPlayers.length === 0}
          <div class="state-message load-state error-state">
            <strong>Couldn’t load players</strong>
            <span>{ratingLoadError}</span>
            <button type="button" class="tiny" disabled={ratingLoading} onclick={() => openSelectedEventRating()}>{ratingLoading ? 'Retrying…' : 'Try again'}</button>
          </div>
        {:else if ratingLoading && ratingPlayers.length === 0}
          <div class="state-message load-state"><strong>Loading players…</strong><span>Getting everyone recorded for this game.</span></div>
        {:else if ratingPlayers.length === 0}
          <div class="state-message">No other players were recorded for this event.</div>
        {:else}
          <div class="rating-list">
            {#each ratingPlayers as player, index (player.id)}
              {@const playerId = player.id}
              {@const playerName = player.name}
              {@const draft = ratingDrafts[playerId] ?? { stars: 0, showedUp: true, skillMatch: true, note: '' }}
              <div class="rating-row" class:rating-complete={draft.stars > 0 || !draft.showedUp}>
                <div class="rating-row-head">
                  <button type="button" class="rating-person profile-trigger" onclick={() => openPlayerProfile(player.id, { name: playerName })}><span class="friend-avatar {avatarColorForId(player.id)}">{playerName[0]?.toUpperCase() ?? '?'}</span><span><strong>{playerName}</strong><small>{player.role}</small></span></button>
                  <span class="rating-row-status">{!draft.showedUp ? 'Didn’t show' : draft.stars > 0 ? `${draft.stars}/5` : 'Not rated'}</span>
                </div>
                <div class="rating-score">
                  <div class="stars" role="radiogroup" aria-label={draft.stars > 0 ? `${draft.stars} out of 5 stars` : 'No rating selected'}>
                    {#each [1, 2, 3, 4, 5] as star}
                      <button
                        type="button"
                        class="star-choice"
                        class:filled={star <= draft.stars}
                        class:selected-star={draft.stars === star}
                        aria-label={`Rate ${playerName} ${star} out of 5 stars`}
                        aria-pressed={draft.stars === star}
                        disabled={!draft.showedUp || ratingLoading}
                        onclick={() => setPlayerRating(playerId, star)}
                      >★</button>
                    {/each}
                  </div>
                  <button
                    type="button"
                    class="rating-stepper"
                    aria-label={`Decrease ${playerName} rating`}
                    disabled={draft.stars <= 0 || !draft.showedUp || ratingLoading}
                    onclick={() => decreasePlayerRating(playerId)}
                  >−</button>
                  <button
                    type="button"
                    class="rating-stepper"
                    aria-label={`Increase ${playerName} rating`}
                    disabled={!draft.showedUp || ratingLoading}
                    onclick={() => increasePlayerRating(playerId)}
                  >+</button>
                </div>
                <span class="rating-value">{draft.stars > 0 ? `${draft.stars}/5` : '—'}</span>
                {#if player.canMarkAttendance}<div class="rating-toggles"><button type="button" class:on={draft.showedUp} disabled={ratingLoading} onclick={() => toggleRatingField(playerId, 'showedUp')}>Showed up</button><button type="button" class:on={draft.skillMatch} disabled={!draft.showedUp || ratingLoading} onclick={() => toggleRatingField(playerId, 'skillMatch')}>Skill match</button></div>{/if}
              </div>
            {/each}
          </div>
          <button class="primary" disabled={ratingLoading} onclick={submitRatings}>{ratingLoading ? 'Submitting…' : 'Submit ratings'}</button>
        {/if}
      </section>
    </div>
  {/if}

  {#if profileSheet === 'profile'}
    <div class="scrim" transition:fade={{ duration: 190 }}>
      <button class="scrim-backdrop" type="button" aria-label="Close edit profile" onclick={() => profileSheet = null}></button>
      <section class="sheet" aria-label="Edit profile" transition:fly={{ y: 34, duration: 260, opacity: 0.98 }}>
        <div class="sheet-head"><div><p class="eyebrow">PROFILE</p><h2>Edit profile</h2></div><button class="round" aria-label="Close" onclick={() => profileSheet = null}><Icon name="close" size={20}/></button></div>
        <div class="form-field"><label for="profile-name">Name</label><input id="profile-name" bind:value={profileDraft.name} placeholder="Your name" onpointerup={focusFormControl} ontouchend={focusFormControl} /></div>
        <div class="form-field"><label for="profile-handle">Handle</label><input id="profile-handle" bind:value={profileDraft.handle} placeholder="@yourhandle" onpointerup={focusFormControl} ontouchend={focusFormControl} /></div>
        <div class="form-field"><label for="profile-bio">Bio</label><textarea id="profile-bio" bind:value={profileDraft.bio} rows="3" placeholder="A short intro" onpointerup={focusFormControl} ontouchend={focusFormControl}></textarea></div>
        <button class="primary" disabled={profileSaving} onclick={saveProfileEditor}>{profileSaving ? 'Saving…' : 'Save profile'}</button>
      </section>
    </div>
  {/if}

  {#if profileSheet === 'sports'}
    <div class="scrim" transition:fade={{ duration: 190 }}>
      <button class="scrim-backdrop" type="button" aria-label="Close sports editor" onclick={() => profileSheet = null}></button>
      <section class="sheet" aria-label="Edit sports" transition:fly={{ y: 34, duration: 260, opacity: 0.98 }}>
        <div class="sheet-head"><div><p class="eyebrow">YOUR PLAY</p><h2>Edit sports</h2></div><button class="round" aria-label="Close" onclick={() => profileSheet = null}><Icon name="close" size={20}/></button></div>
        <div class="sport-grid profile-sport-grid selection-grid">
          {#each sports.slice(1) as sport}
            <button type="button" class:selected={sportsDraft.includes(sport)} onclick={() => toggleProfileSport(sport)}>{sport}<span>{sportsDraft.includes(sport) ? '✓' : '+'}</span></button>
          {/each}
        </div>
        {#if sportsDraft.length}
          <div class="levels profile-levels selection-section"><div class="section-head"><h2>Skill levels</h2><span>{sportsDraft.length} selected</span></div>
            {#each sportsDraft as sport}
              <div class="level-row">
                <div class="level-row-head"><strong>{sport}</strong><span>Choose your level</span></div>
                <div class="choice-list profile-skill-list">
                  {#each skillLevels as level}
                    <button type="button" class:selected-choice={skillsDraft[sport] === level} onclick={() => skillsDraft = { ...skillsDraft, [sport]: level }}>
                      <span class="choice-option-icon">{skillLevels.indexOf(level) + 1}</span>
                      <span class="choice-option-copy">
                        <strong>{level}</strong>
                        <small>{level === 'Beginner' ? 'New to the sport' : level === 'Amateur' ? 'Some experience and basic confidence' : level === 'Intermediate' ? 'Comfortable playing full games' : level === 'Seasoned' ? 'Strong, experienced player' : 'High-level competitive player'}</small>
                      </span>
                      <span class="choice-check">{skillsDraft[sport] === level ? '✓' : ''}</span>
                    </button>
                  {/each}
                </div>
              </div>
            {/each}
          </div>
        {/if}
        <button class="primary" disabled={sportsSaving} onclick={saveSportsEditor}>{sportsSaving ? 'Saving…' : 'Save sports'}</button>
      </section>
    </div>
  {/if}

  {#if profileSheet === 'events'}
    <div class="scrim" transition:fade={{ duration: 190 }}>
      <button class="scrim-backdrop" type="button" aria-label="Close your events" onclick={() => profileSheet = null}></button>
      <section class="sheet events-sheet" aria-label="Your events" transition:fly={{ y: 34, duration: 260, opacity: 0.98 }}>
        <div class="sheet-head"><div><p class="eyebrow">YOUR PLAY</p><h2>Your events</h2></div><button class="round" aria-label="Close" onclick={() => profileSheet = null}><Icon name="close" size={20}/></button></div>
        <div class="events-segment" role="tablist" aria-label="Event lists">
          <button type="button" class:active={eventsSegment === 'joined'} role="tab" aria-selected={eventsSegment === 'joined'} onclick={() => openEventsSheet('joined')}>Joined</button>
          <button type="button" class:active={eventsSegment === 'hosted'} role="tab" aria-selected={eventsSegment === 'hosted'} onclick={() => openEventsSheet('hosted')}>Hosted</button>
        </div>
        {#if sortedEvents.length === 0}
          <div class="state-message">{eventsSegment === 'joined' ? 'You have not joined any games yet.' : 'You have not hosted any games yet.'}</div>
        {:else}
          <div class="events-list">
            {#each sortedEvents as event (event.id)}
              <button type="button" class="event-list-row" onclick={() => openEvent(event)}>
                <span class="event-list-accent {event.color}"></span>
                <span class="event-list-copy"><strong>{event.title}</strong><small>{event.eventType === 'esports' ? `Esports · ${event.sport}` : event.sport} · {event.date}</small><span>{event.members}/{event.capacity} players · {event.location}</span></span>
                <span class="event-list-side"><span class="event-status-mini {event.status ?? 'upcoming'}">{event.status === 'completed' ? 'Completed' : event.status === 'cancelled' ? 'Cancelled' : event.status === 'full' ? 'Full' : 'Upcoming'}</span><Icon name="chevron" size={17}/></span>
              </button>
            {/each}
          </div>
        {/if}
      </section>
    </div>
  {/if}

  {#if profileSheet === 'account'}
    <div class="scrim" transition:fade={{ duration: 190 }}>
      <button class="scrim-backdrop" type="button" aria-label="Close account settings" onclick={() => profileSheet = null}></button>
      <section class="sheet" aria-label="Account settings" transition:fly={{ y: 34, duration: 260, opacity: 0.98 }}>
        <div class="sheet-head"><div><p class="eyebrow">ACCOUNT</p><h2>Account settings</h2></div><button class="round" aria-label="Close" onclick={() => profileSheet = null}><Icon name="close" size={20}/></button></div>
        <div class="setting-card"><span><strong>Email</strong><small>{session?.email ?? 'Not set'}</small></span><span class="setting-value">Verified</span></div>
        <div class="form-field"><label for="account-phone">Phone</label><input id="account-phone" bind:value={userProfile.phone} placeholder="Optional phone number" inputmode="tel" onpointerup={focusFormControl} ontouchend={focusFormControl} /></div>
        <button class="secondary" onclick={openPasswordSheet}>Change password</button>
        <button class="primary" disabled={accountSaving} onclick={saveAccountSettings}>{accountSaving ? 'Saving…' : 'Save account'}</button>
      </section>
    </div>
  {/if}

  {#if passwordSheetOpen}
    <div class="scrim" transition:fade={{ duration: 190 }}>
      <button class="scrim-backdrop" type="button" aria-label="Close change password" onclick={closePasswordSheet}></button>
      <section class="sheet" aria-label="Change password" transition:fly={{ y: 34, duration: 260, opacity: 0.98 }}>
        <div class="sheet-head"><div><p class="eyebrow">SECURITY</p><h2>Change password</h2></div><button class="round" aria-label="Close" onclick={closePasswordSheet}><Icon name="close" size={20}/></button></div>
        <p class="sheet-note">Use a new password for your Huddl account.</p>
        <div class="form-field"><label for="new-password">New password</label><input id="new-password" type="password" bind:value={passwordDraft.password} autocomplete="new-password" minlength="6" placeholder="At least 6 characters" onpointerup={focusFormControl} ontouchend={focusFormControl} /></div>
        <div class="form-field"><label for="confirm-new-password">Confirm password</label><input id="confirm-new-password" type="password" bind:value={passwordDraft.confirmPassword} autocomplete="new-password" minlength="6" placeholder="Enter it again" onpointerup={focusFormControl} ontouchend={focusFormControl} /></div>
        <button class="primary" disabled={passwordSaving} onclick={changePassword}>{passwordSaving ? 'Updating…' : 'Update password'}</button>
      </section>
    </div>
  {/if}

  {#if profileSheet === 'notifications'}
    <div class="scrim" transition:fade={{ duration: 190 }}>
      <button class="scrim-backdrop" type="button" aria-label="Close preferences" onclick={() => profileSheet = null}></button>
      <section class="sheet" aria-label="Notification preferences" transition:fly={{ y: 34, duration: 260, opacity: 0.98 }}>
        <div class="sheet-head"><div><p class="eyebrow">PREFERENCES</p><h2>Notification preferences</h2></div><button class="round" aria-label="Close" onclick={() => profileSheet = null}><Icon name="close" size={20}/></button></div>
        <button class="toggle-row" type="button" onclick={() => settingsDraft = { ...settingsDraft, eventNotifications: !settingsDraft.eventNotifications }}><span><strong>Event updates</strong><small>Changes, join requests and cancellations</small></span><span class:on={settingsDraft.eventNotifications} class="toggle"><span></span></span></button>
        <button class="toggle-row" type="button" onclick={() => settingsDraft = { ...settingsDraft, friendNotifications: !settingsDraft.friendNotifications }}><span><strong>Friend updates</strong><small>Requests and connection changes</small></span><span class:on={settingsDraft.friendNotifications} class="toggle"><span></span></span></button>
        <button class="toggle-row" type="button" onclick={() => settingsDraft = { ...settingsDraft, ratingNotifications: !settingsDraft.ratingNotifications }}><span><strong>Rating reminders</strong><small>Prompts after completed games</small></span><span class:on={settingsDraft.ratingNotifications} class="toggle"><span></span></span></button>
        <button class="toggle-row" type="button" onclick={() => settingsDraft = { ...settingsDraft, showContact: !settingsDraft.showContact }}><span><strong>Show contact number</strong><small>Visible on your profile when added</small></span><span class:on={settingsDraft.showContact} class="toggle"><span></span></span></button>
        <button class="primary" disabled={settingsSaving} onclick={saveSettings}>{settingsSaving ? 'Saving…' : 'Save preferences'}</button>
      </section>
    </div>
  {/if}

  {#if selectedPlayerProfile}
    <div class="scrim" transition:fade={{ duration: 190 }}>
      <button class="scrim-backdrop" type="button" aria-label="Close player profile" onclick={closePlayerProfile}></button>
      <section class="sheet player-profile-sheet" aria-label={`${selectedPlayerProfile.name} profile`} transition:fly={{ y: 34, duration: 260, opacity: 0.98 }}>
        <div class="sheet-head"><div><p class="eyebrow">PLAYER PROFILE</p><h2>{selectedPlayerProfile.name}</h2></div><button class="round" aria-label="Close" onclick={closePlayerProfile}><Icon name="close" size={20}/></button></div>
        <div class="player-profile-hero">
          <span class="profile-avatar {avatarColorForId(selectedPlayerProfile.id)}">{selectedPlayerProfile.name?.[0]?.toUpperCase() ?? 'P'}</span>
          <strong>{selectedPlayerProfile.handle}</strong>
          <p>{selectedPlayerProfile.bio}</p>
          {#if selectedPlayerProfile.phone}
            <span class="profile-status">{selectedPlayerProfile.phone}</span>
          {/if}
          {#if selectedPlayerProfile.relation === 'friend'}<span class="profile-status">Friends · {selectedPlayerProfile.status ?? 'connected'}</span>{/if}
        </div>
        {#if profileLoadError}
          <div class="state-message load-state error-state">
            <strong>Couldn’t load this profile</strong>
            <span>{profileLoadError}</span>
            <button type="button" class="tiny" disabled={playerProfileLoading} onclick={retrySelectedPlayerProfile}>{playerProfileLoading ? 'Retrying…' : 'Try again'}</button>
          </div>
        {:else if playerProfileLoading}
          <div class="state-message load-state"><strong>Loading profile…</strong><span>Getting stats and sports.</span></div>
        {:else if selectedPlayerProfile.stats}
          {@const playerStats = selectedPlayerProfile.stats}
          <div class="stat-grid profile-stat-grid">
            <div><strong>{playerStats.games}</strong><span>Games</span></div>
            <div><strong>{playerStats.hosted}</strong><span>Hosted</span></div>
            <div><strong>{playerStats.rating === null ? '—' : playerStats.rating.toFixed(1)}</strong><span>Rating</span></div>
            <div><strong>{playerStats.attendance === null ? '—' : `${playerStats.attendance}%`}</strong><span>Attendance</span></div>
          </div>
          <section class="panel"><div class="panel-head"><h2>Sports</h2></div>{#if selectedPlayerProfile.sports.length === 0}<div class="state-message">No sports added.</div>{:else}<div class="profile-sport-list">{#each selectedPlayerProfile.sports as sport, index}<div><strong>{sport}</strong><span>{selectedPlayerProfile.skills[index] ?? 'Intermediate'}</span></div>{/each}</div>{/if}</section>
          <section class="panel"><div class="panel-head"><h2>Games by sport</h2></div>{#if playerStats.sports.length === 0}<div class="state-message">No completed games yet.</div>{:else}{@const maxPlayerSportGames = Math.max(...playerStats.sports.map((sport) => sport.games), 1)}{#each playerStats.sports as sport}<div class="bar-row"><div><span>{sport.name}</span><strong>{sport.games}</strong></div><div class="bar"><span style={`width:${Math.round((sport.games / maxPlayerSportGames) * 100)}%`}></span></div></div>{/each}{/if}</section>
        {/if}
      </section>
    </div>
  {/if}

  {#if showCreate || showEdit}
    {@const form = showEdit ? editEvent : newEvent}
    <div class="scrim" transition:fade={{ duration: 190 }}>
      <button class="scrim-backdrop" type="button" aria-label="Close event form" onclick={() => { showCreate = false; showEdit = false; }}></button>
      <section class="sheet event-editor-sheet" aria-label={showEdit ? 'Edit event' : 'Create event'} transition:fly={{ y: 34, duration: 260, opacity: 0.98 }}>
        <div class="sheet-head"><div><p class="eyebrow">{showEdit ? 'EDIT EVENT' : 'NEW EVENT'}</p><h2>{showEdit ? 'Update your game' : 'Create a game'}</h2></div><button class="round" aria-label="Close" onclick={() => { showCreate=false; showEdit=false; }}><Icon name="close" size={20}/></button></div>
        <div class="form-field"><label for="event-title">Title</label><input id="event-title" bind:value={form.title} placeholder="e.g. Friday Night Football" onpointerup={focusFormControl} ontouchend={focusFormControl} /></div>
        <div class="form-field selector-field">
          <span class="field-label">Event type</span>
          <button type="button" class="choice-button" disabled={showEdit} onclick={() => { if (!showEdit) { eventTypeOpen = !eventTypeOpen; eventSportOpen = false; eventGameOpen = false; eventSkillOpen = false; visibilityOpen = false; } }}>
            <span><strong>{form.eventType === 'esports' ? 'Esports' : 'Sport'}</strong><small>{form.eventType === 'esports' ? 'Create a competitive game event' : 'Create a regular sports game'}</small></span><Icon name="chevron" size={17}/>
          </button>
          {#if eventTypeOpen}<div class="choice-popover sport-popover" transition:slide={{ duration: 170 }}><div class="choice-grid">
            <button type="button" class="event-type-choice sport-option" class:selected-choice={form.eventType === 'sport'} onclick={() => setEventType(form, 'sport')}><span>Sport</span><span class="choice-check">{form.eventType === 'sport' ? '✓' : ''}</span></button>
            <button type="button" class="event-type-choice esports-option" class:selected-choice={form.eventType === 'esports'} onclick={() => setEventType(form, 'esports')}><span>Esports</span><span class="choice-check">{form.eventType === 'esports' ? '✓' : ''}</span></button>
          </div></div>{/if}
          {#if showEdit}<small class="form-hint">Event type cannot be changed after creation.</small>{/if}
        </div>

        {#if form.eventType === 'sport'}
          <div class="form-field selector-field"><span class="field-label">Sport</span><button type="button" class="choice-button" onclick={() => { eventSportOpen = !eventSportOpen; eventGameOpen = false; eventTypeOpen = false; eventSkillOpen = false; visibilityOpen = false; }}><span><strong>{form.sport}</strong><small>Choose the sport you are playing</small></span><Icon name="chevron" size={17}/></button>{#if eventSportOpen}<div class="choice-popover sport-popover" transition:slide={{ duration: 170 }}><div class="choice-grid">{#each sports.slice(1) as sport}<button type="button" class:selected-choice={form.sport === sport} onclick={() => { if (showEdit) editEvent = { ...form, sport }; else newEvent = { ...form, sport }; eventSportOpen = false; }}><span>{sport}</span><span class="choice-check">{form.sport === sport ? '✓' : ''}</span></button>{/each}</div></div>{/if}</div>
        {:else}
          <div class="form-field selector-field"><span class="field-label">Game</span><button type="button" class="choice-button" disabled={esportsGames.length === 0} onclick={() => { eventGameOpen = !eventGameOpen; eventSportOpen = false; eventTypeOpen = false; eventSkillOpen = false; visibilityOpen = false; }}><span><strong>{esportsGames.find((game) => game.id === form.gameId)?.name ?? (esportsGames.length ? 'Choose a game' : 'No esports games available')}</strong><small>Choose the esports game you are playing</small></span><Icon name="chevron" size={17}/></button>{#if eventGameOpen}<div class="choice-popover sport-popover" transition:slide={{ duration: 170 }}><div class="choice-grid">{#each esportsGames as game (game.id)}<button type="button" class:selected-choice={form.gameId === game.id} onclick={() => { if (showEdit) editEvent = { ...form, gameId: game.id }; else newEvent = { ...form, gameId: game.id }; eventGameOpen = false; }}><span>{game.name}</span><span class="choice-check">{form.gameId === game.id ? '✓' : ''}</span></button>{/each}</div></div>{/if}</div>
          <div class="form-field"><label for="event-platform">Platform</label><input id="event-platform" bind:value={form.platform} placeholder="PC, console, mobile or cross-platform" onpointerup={focusFormControl} ontouchend={focusFormControl} /></div>
          <div class="two">
            <div class="form-field"><label for="event-mode">Game mode</label><input id="event-mode" bind:value={form.gameMode} placeholder="e.g. 5v5" onpointerup={focusFormControl} ontouchend={focusFormControl} /></div>
          </div>
        {/if}
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
          <div class="picker-popover calendar-popover" transition:slide={{ duration: 190 }}>
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
          <div class="picker-popover time-popover" transition:slide={{ duration: 190 }}>
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
        <div class="form-field selector-field"><span class="field-label">Visibility</span><button type="button" class="choice-button" onclick={() => { eventSkillOpen = false; eventSportOpen = false; visibilityOpen = !visibilityOpen; }}><span><strong>{form.visibility}</strong><small>{form.visibility === 'Public' ? 'Anyone can find and join' : 'People request access to join'}</small></span><Icon name="chevron" size={17}/></button>{#if visibilityOpen}<div class="choice-popover visibility-popover" transition:slide={{ duration: 170 }}><div class="choice-list">{#each ['Public','Private'] as visibility}<button type="button" class:selected-choice={form.visibility === visibility} onclick={() => { if (showEdit) editEvent = { ...form, visibility }; else newEvent = { ...form, visibility }; visibilityOpen = false; }}><span class="choice-option-icon">{visibility === 'Public' ? 'P' : 'R'}</span><span class="choice-option-copy"><strong>{visibility}</strong><small>{visibility === 'Public' ? 'Anyone can find and join' : 'Only people you approve can join'}</small></span><span class="choice-check">{form.visibility === visibility ? '✓' : ''}</span></button>{/each}</div></div>{/if}</div>
        <div class="form-field"><label for="event-location">Location</label><input id="event-location" bind:value={form.location} placeholder="Court, park or arena" onpointerup={focusFormControl} ontouchend={focusFormControl} /></div>
        <div class="form-field selector-field"><span class="field-label">Skill level</span><button type="button" class="choice-button" onclick={() => { eventSkillOpen = !eventSkillOpen; eventSportOpen = false; eventGameOpen = false; eventTypeOpen = false; visibilityOpen = false; }}><span><strong>{form.skill}</strong><small>Set the level expected for this game</small></span><Icon name="chevron" size={17}/></button>{#if eventSkillOpen}<div class="choice-popover skill-popover" transition:slide={{ duration: 170 }}><div class="choice-list skill-option-list">{#each skillLevels as level}<button type="button" class:selected-choice={form.skill === level} onclick={() => { if (showEdit) editEvent = { ...form, skill: level }; else newEvent = { ...form, skill: level }; eventSkillOpen = false; }}><span class="choice-option-icon">{skillLevels.indexOf(level) + 1}</span><span class="choice-option-copy"><strong>{level}</strong><small>{level === 'Beginner' ? 'New to the sport or game' : level === 'Amateur' ? 'Some experience and basic confidence' : level === 'Intermediate' ? 'Comfortable playing full games' : level === 'Seasoned' ? 'Strong, experienced player' : 'High-level competitive player'}</small></span><span class="choice-check">{form.skill === level ? '✓' : ''}</span></button>{/each}</div></div>{/if}</div>
        <div class="form-field"><label for="event-description">Description</label><textarea id="event-description" bind:value={form.description} placeholder="Anything players should know?" rows="3" onpointerup={focusFormControl} ontouchend={focusFormControl}></textarea></div>
        <button class="primary" disabled={showEdit ? eventSaving : creatingEvent} onclick={showEdit ? saveEdit : create}>{showEdit ? (eventSaving ? 'Saving…' : 'Save changes') : creatingEvent ? 'Creating…' : 'Create event'}</button>
      </section>
    </div>
  {/if}
  {#if notice}<div class="toast" transition:fly={{ y: 10, duration: 150, opacity: 0 }}>{notice}</div>{/if}
</div>
{/if}

<style>
  .auth-loading{min-height:100vh;background:#fbfbfb;display:grid;place-items:center;color:#777;font:800 12px Quicksand,sans-serif}
  :global(*){box-sizing:border-box}:global(html,body){margin:0;min-height:100%;background:#161616;color:#171717;font-family:Nunito,Arial,sans-serif}:global(button),:global(input),:global(select),:global(textarea){font:inherit} :global(input),:global(textarea),:global(select){font-size:16px !important;line-height:1.2;-webkit-text-size-adjust:100%}:global(button){cursor:pointer}:global(button:disabled){cursor:default;opacity:.62}:global(button:disabled:active){transform:none !important}.primary:disabled,.secondary:disabled,.danger:disabled,.accept:disabled,.decline:disabled,.tiny:disabled{box-shadow:-2px 3px 0 #ddd}.chat-send:disabled{opacity:.55}.app-shell{min-height:100vh;width:min(100%,430px);margin:0 auto;background:#fbfbfb;position:relative}.screen{min-height:100vh;padding:25px 16px calc(130px + env(safe-area-inset-bottom))}.toolbar,.page-head,.profile-head,.sheet-head,.panel-head{display:flex;align-items:center;justify-content:space-between}.toolbar{margin-bottom:22px;gap:16px}.eyebrow{margin:0 0 5px;font:800 12px Quicksand,sans-serif;letter-spacing:.09em}.toolbar h1,.page-head h1{margin:0;font:900 28px/1.05 Nunito,sans-serif;letter-spacing:-.025em}.avatar,.round{border:2px solid #171717;background:#ffe5d4;border-radius:50%;width:44px;height:44px;display:grid;place-items:center;font-weight:900;box-shadow:-4px 5px 0 #a1a2a4}.round{background:#fff;box-shadow:none;width:42px;height:42px}.filters{display:flex;gap:8px;overflow:auto;scrollbar-width:none;margin-bottom:28px;padding:3px 2px 8px}.filters::-webkit-scrollbar{display:none}.filters button,.pill{border:2px solid #171717;background:#fff;border-radius:999px;padding:9px 14px;font:700 13px Quicksand,sans-serif;letter-spacing:.005em;word-spacing:.02em;white-space:nowrap}.filters .chosen{background:#e9e5ff;box-shadow:-3px 4px 0 #a1a2a4}.home-filters{position:relative;overflow:visible}.home-filters .esports-filter-button{background:#fbf1f3;border-color:#d98a94!important;color:#a94d55}.home-filters .esports-filter-button.chosen{background:#f8dfe3;box-shadow:-3px 4px 0 #a1a2a4}
.home-filters .sports-filter-button{background:#f7f5ff;border-color:#b7afe8!important;color:#675db5}
.home-filters .sports-filter-button.chosen{background:#e9e5ff;box-shadow:-3px 4px 0 #a1a2a4}.home-filter-popover{margin:-18px 0 20px;border:2px solid #171717;border-radius:19px;background:#fff;box-shadow:-5px 6px 0 #a1a2a4;position:relative;z-index:30;overflow:hidden;display:grid;gap:7px;padding:10px}.home-filter-popover button.home-filter-option{min-height:46px;border:1.5px solid #171717;border-radius:13px;background:#fbfbfb;padding:9px 11px;display:flex;align-items:center;justify-content:space-between;text-align:left;font:900 12px Nunito;box-shadow:-2px 3px 0 #e1e1e1}.home-filter-popover button.home-filter-option:active{transform:translate(-1px,1px);box-shadow:-1px 2px 0 #e1e1e1}.home-filter-popover button.home-filter-option.sports-option.selected-choice{background:#e9e5ff;box-shadow:-2px 3px 0 #a1a2a4}.home-filter-popover button.home-filter-option.esports-option.selected-choice{background:#f8dfe3;color:#a94d55;box-shadow:-2px 3px 0 #a1a2a4}.home-filter-popover button.home-filter-option.esports-option .choice-check{color:#a94d55}.home-filter-empty{padding:10px 11px;color:#777;font:700 11px Quicksand;text-align:center}.section-head{display:flex;align-items:baseline;justify-content:space-between;margin-bottom:15px}.section-head h2,.panel h2{margin:0;font:900 21px Nunito,sans-serif}.section-head span,.muted{color:#777;font:700 12px Quicksand,sans-serif}.discovery-head{align-items:center;gap:10px}.discovery-head>div:first-child{display:grid;gap:3px;min-width:0}.discovery-sort{display:flex;flex:0 0 auto;border:1.5px solid #171717;border-radius:12px;background:#fff;padding:2px;box-shadow:-2px 3px 0 #ddd}.discovery-sort button{border:0;border-radius:9px;background:transparent;padding:6px 8px;font:800 9px Quicksand;color:#777}.discovery-sort button.chosen{background:#e9e5ff;color:#171717}.event-search{height:48px;border:2px solid #171717;border-radius:17px;background:#fff;display:flex;align-items:center;gap:9px;padding:0 9px 0 13px;box-shadow:-3px 4px 0 #ddd;margin:-2px 0 18px}.event-search input{border:0;outline:0;background:transparent;width:100%;min-width:0;font:700 14px Quicksand,sans-serif}.event-search-clear{width:32px;height:32px;border:1.5px solid #171717;border-radius:10px;background:#f8f8f8;display:grid;place-items:center;flex:0 0 auto}.home-empty-state{display:grid;justify-items:center;gap:7px;padding:20px 16px}.home-empty-state strong{font:900 15px Nunito}.home-empty-state span{max-width:285px;color:#777;font:700 11px/1.4 Quicksand;text-align:center}.home-empty-state .tiny{margin-top:4px;background:#e9e5ff}.event-discovery-item{min-width:0}.feed{display:grid;gap:18px}.create{position:fixed;right:max(24px,calc(50% - 191px));bottom:calc(103px + env(safe-area-inset-bottom));width:54px;height:54px;border:2px solid #171717;border-radius:18px;background:#dcecff;display:grid;place-items:center;box-shadow:-5px 6px 0 #a1a2a4;z-index:71}.chat-fab{position:fixed;left:max(24px,calc(50% - 191px));bottom:calc(103px + env(safe-area-inset-bottom));width:54px;height:54px;border:2px solid #171717;border-radius:18px;background:#e9e5ff;display:grid;place-items:center;box-shadow:5px 6px 0 #a1a2a4;z-index:71;touch-action:manipulation;-webkit-tap-highlight-color:transparent}.page-head{margin-bottom:20px}.search{height:48px;border:2px solid #171717;border-radius:17px;background:#fff;display:flex;align-items:center;gap:9px;padding:0 13px;box-shadow:-3px 4px 0 #ddd;margin-bottom:15px}.search input{border:0;outline:0;background:transparent;width:100%;font:700 14px Quicksand,sans-serif}.request{border:2px solid #171717;border-radius:20px;background:#f1edff;padding:13px 14px;display:flex;justify-content:space-between;align-items:center;margin-bottom:20px;box-shadow:-4px 5px 0 #a1a2a4}.request div{display:grid;gap:3px}.request span{font:700 11px Quicksand;color:#777}.tiny{border:1.5px solid #171717;border-radius:999px;background:#fff;padding:7px 11px;font:800 11px Quicksand}.list{display:grid;gap:9px}.compact-panel{padding:15px;margin-bottom:22px}.compact-panel .panel-head{margin-bottom:10px}.request-count{font:800 11px Quicksand;color:#777}.request-row{display:grid;grid-template-columns:44px minmax(0,1fr) auto auto;align-items:center;gap:7px;padding:9px 0;border-top:1px solid #ddd}.request-row:first-of-type{border-top:0}.request-action{border:1.5px solid #171717;border-radius:999px;padding:7px 9px;font:800 10px Quicksand}.request-action.accept{background:#ddf3e7}.request-action.decline{background:#fff}.friends-section{margin-bottom:24px}.friend-main{border:0;background:transparent;padding:0;display:flex;align-items:center;text-align:left;gap:11px;min-width:0;flex:1}.friend-row{border:0;background:#fff;border-bottom:1px solid #ddd;padding:9px 2px;display:flex;align-items:center;text-align:left;gap:9px}.friend-profile-sheet{text-align:left}.friend-profile-card{display:grid;justify-items:center;gap:7px;padding:10px 0 20px}.friend-profile-card .profile-avatar{width:78px;height:78px;flex-basis:78px;font-size:25px}.friend-avatar,.profile-avatar{width:44px;height:44px;border:2px solid #171717;border-radius:50%;display:grid;place-items:center;font-weight:900;flex:0 0 44px}.friend-avatar.blue{background:#dcecff}.friend-avatar.peach{background:#ffe5d4}.friend-avatar.lavender{background:#e9e5ff}.friend-avatar.mint{background:#ddf3e7}.profile-avatar.blue{background:#dcecff}.profile-avatar.peach{background:#ffe5d4}.profile-avatar.lavender{background:#e9e5ff}.profile-avatar.mint{background:#ddf3e7}.friend-copy{display:grid;gap:2px;flex:1}.friend-copy strong{font:900 15px Nunito}.friend-copy small,.status{font:700 11px Quicksand;color:#777}.status{font-size:10px}.stat-grid{display:grid;grid-template-columns:1fr 1fr;gap:11px;margin:24px 0 20px}.stat-grid div{background:#fff;border:2px solid #171717;border-radius:20px;padding:17px;box-shadow:-4px 5px 0 #a1a2a4;display:grid;gap:3px}.stat-grid strong{font:900 27px Nunito}.stat-grid span{font:700 11px Quicksand;color:#777}.stats-hero{margin:22px 0 14px;border:2px solid #171717;border-radius:24px;background:#e9e5ff;padding:17px;box-shadow:-5px 6px 0 #a1a2a4}.stats-hero-top{display:flex;align-items:flex-start;justify-content:space-between;gap:12px}.stats-hero-top>div:first-child{display:grid;gap:2px;min-width:0}.stats-hero-top .eyebrow{margin:0 0 3px;font-size:9px}.stats-hero-top strong{font:900 39px/1 Nunito;letter-spacing:-.035em}.stats-hero-top span{color:#666;font:700 10px Quicksand}.stats-hero-badge{display:flex;align-items:center;gap:6px;border:1.5px solid #171717;border-radius:999px;background:#fff;padding:7px 9px;white-space:nowrap;font:900 10px Quicksand}.stats-hero-meta{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:15px}.stats-hero-meta div{border:1.5px solid #171717;border-radius:15px;background:rgba(255,255,255,.65);padding:10px 11px;display:grid;gap:2px}.stats-hero-meta strong{font:900 18px Nunito}.stats-hero-meta span{font:700 9px Quicksand;color:#777}.panel{background:#fff;border:2px solid #171717;border-radius:22px;padding:17px;box-shadow:-5px 6px 0 #a1a2a4;margin-bottom:18px}.stats-sport-panel .panel-head{align-items:flex-start}.stats-sport-panel .panel-head>div{display:grid;gap:2px}.stats-sport-panel .panel-head strong{min-width:28px;height:28px;display:grid;place-items:center;border:1.5px solid #171717;border-radius:10px;background:#f8f8f8}.stats-bars{display:grid;gap:2px}.stats-bars .bar-row{padding:5px 0}.stats-bars .bar-row>div:first-child{font-size:11px}.stats-bars .bar{height:10px;background:#f0f0f0}.stats-bars .bar span{background:#7e9fe7}.players-panel .panel-head>div{display:grid;gap:3px}.panel-subtitle{font:700 9px Quicksand;color:#888}.players-panel .panel-head strong{font-size:14px}.player-count-line{display:flex;justify-content:space-between;gap:10px;margin-top:6px;color:#888;font:700 9px Quicksand}.players-panel .avatars{margin-top:14px;padding-left:2px}.panel-head{margin-bottom:16px}.panel-head strong{font:900 13px Quicksand}.big-progress,.bar{height:9px;background:#eee;border:1.5px solid #171717;border-radius:99px;overflow:hidden}.big-progress span,.bar span{display:block;height:100%;background:#7e9fe7;border-radius:99px}.avatars{display:flex;margin-top:15px}.avatars span{width:31px;height:31px;border:2px solid #171717;border-radius:50%;background:#ffe5d4;display:grid;place-items:center;font:800 10px Quicksand;margin-right:-5px}.avatars .empty{background:#fff}.bar-row{margin-top:14px}.bar-row>div:first-child{display:flex;justify-content:space-between;font:700 12px Quicksand;margin-bottom:5px}.profile-head{justify-content:flex-start;gap:12px}.profile-head .round{margin-left:auto}.profile-avatar{width:62px;height:62px;flex-basis:62px;background:#ffe5d4;font-size:20px}.profile-head h1{margin:0;font:900 22px Nunito}.profile-head p,.bio{margin:3px 0 0;color:#777;font:700 12px Quicksand}.bio{margin:20px 0}.sport-row{display:flex;justify-content:space-between;padding:12px 0;border-top:1px solid #ddd;font:800 13px Quicksand}.sport-row span:last-child{color:#777}.settings{display:grid;border:2px solid #171717;border-radius:20px;background:#fff;overflow:hidden;box-shadow:-4px 5px 0 #a1a2a4}.settings button{border:0;border-bottom:1px solid #ddd;background:#fff;padding:16px;text-align:left;display:flex;justify-content:space-between;align-items:center;font:800 13px Quicksand}.settings button:last-child{border-bottom:0;color:#b34a4a}.detail-screen{padding-top:20px}.back{width:43px;height:43px;border:2px solid #171717;border-radius:50%;background:#fff;display:grid;place-items:center;margin-bottom:16px}.detail-hero{border:2px solid #171717;border-radius:25px;padding:20px;box-shadow:-6px 7px 0 #a1a2a4;overflow:hidden;position:relative}.detail-hero:after{content:"";position:absolute;right:-32px;bottom:-42px;width:120px;height:120px;border:2px solid rgba(23,23,23,.09);border-radius:50%}.detail-hero.blue{background:#eef6ff}.detail-hero.peach{background:#fff0e7}.detail-hero.lavender{background:#f2efff}.detail-hero.mint{background:#e9f8f0}.detail-hero.esports{background:#f8dfe3}:global(.card.esports){background:#f8dfe3;border-color:#171717}:global(.card.esports .topline span:first-child){background:#f8dfe3;color:#a94d55}:global(.card.esports .progressbar>div){background:#df8f99}.detail-hero.esports .pill{background:#f8dfe3;color:#a94d55}.event-list-accent.esports{background:#ef9ca7}.event-status-mini.esports{background:#f8dfe3}.esports-filter-button{border-color:#d98a94!important}.hero-row{display:flex;align-items:center;justify-content:space-between;gap:10px;position:relative;z-index:1}.hero-row>div{display:flex;align-items:center;gap:8px;min-width:0}.hero-tags{min-width:0}.skill-tag{border:1.5px solid #171717;border-radius:999px;padding:5px 8px;background:rgba(255,255,255,.64);font:800 9px Quicksand;color:#5f5f5f;white-space:nowrap}.status-pill{border:1.5px solid #171717;border-radius:999px;padding:5px 8px;background:#fff;font:800 10px Quicksand}.status-pill.full{background:#ffe9bf}.status-pill.completed{background:#ddf3e7}.status-pill.cancelled{background:#ffe1e1}.hero-copy{position:relative;z-index:1}.detail-hero h1{font:900 30px/1.02 Nunito;margin:18px 0 10px;letter-spacing:-.03em;overflow-wrap:anywhere}.detail-hero p{margin:0;color:#555;font:700 13px/1.45 Quicksand}.detail-grid{display:grid;grid-template-columns:1fr 1fr;gap:9px;margin:17px 0 16px}.detail-grid div{display:grid;grid-template-columns:22px minmax(0,1fr);align-items:center;gap:8px;min-width:0;background:#fff;border:2px solid #171717;border-radius:17px;padding:12px;font:800 11px/1.2 Quicksand;box-shadow:-2px 3px 0 #e3e3e3}.detail-grid div span{min-width:0;overflow-wrap:anywhere}.host-line{display:flex;align-items:center;gap:4px;margin:5px 3px 19px;color:#777;font:700 11px Quicksand}.primary{width:100%;border:2px solid #171717;border-radius:18px;background:#171717;color:#fff;padding:14px;font:900 14px Quicksand;box-shadow:-5px 6px 0 #a1a2a4}.join-actions{display:grid;gap:10px}.secondary,.danger{width:100%;border:2px solid #171717;border-radius:17px;background:#fff;color:#171717;padding:12px;font:900 13px Quicksand;display:flex;align-items:center;justify-content:center;gap:7px}.danger{background:#ffe7e7}.host-actions{display:grid;gap:10px}.request-box{border:2px solid #171717;border-radius:19px;background:#f1edff;padding:14px;display:grid;gap:12px;box-shadow:-4px 5px 0 #a1a2a4}.request-box>div:first-child{display:grid;gap:4px}.request-box strong{font:900 14px Nunito}.request-box span{font:700 11px Quicksand;color:#777}.request-actions{display:grid;grid-template-columns:1fr 1fr;gap:8px}.accept,.decline{border:1.5px solid #171717;border-radius:13px;padding:9px;font:900 11px Quicksand;background:#ddf3e7}.decline{background:#fff}.state-message{border:2px solid #171717;border-radius:17px;background:#fff;padding:14px;text-align:center;font:800 12px Quicksand;box-shadow:-3px 4px 0 #ddd}.mock-tools{border:1.5px dashed #777;border-radius:16px;background:#f8f8f8;padding:10px 11px;display:flex;align-items:center;justify-content:space-between;gap:10px}.mock-tools>div{display:grid;gap:3px}.mock-tools span{font:700 10px/1.3 Quicksand;color:#777}.mock-tools .tiny{flex:0 0 auto}
.toolbar-actions{display:flex;align-items:center;gap:10px}.notification-button{position:relative;width:44px;height:44px;border:2px solid #171717;border-radius:50%;background:#fff;display:grid;place-items:center;box-shadow:-4px 5px 0 #a1a2a4}.notification-dot{position:absolute;right:-4px;top:-4px;min-width:18px;height:18px;padding:0 4px;border:1.5px solid #171717;border-radius:99px;background:#ffe5d4;display:grid;place-items:center;font:900 9px Quicksand}.setting-badge{margin-left:auto;min-width:20px;height:20px;padding:0 5px;border:1.5px solid #171717;border-radius:99px;background:#dcecff;display:grid;place-items:center;font:900 9px Quicksand}.notification-list{display:grid;gap:8px;margin-bottom:12px}.notification-row{width:100%;border:2px solid #171717;border-radius:17px;background:#fff;padding:12px;display:grid;grid-template-columns:38px minmax(0,1fr) 8px;gap:10px;text-align:left;align-items:center}.notification-row.unread{background:#eef6ff}.notification-icon{width:38px;height:38px;border:1.5px solid #171717;border-radius:13px;background:#fff;display:grid;place-items:center}.notification-copy{display:grid;gap:3px}.notification-copy strong{font:900 14px Nunito}.notification-copy span{font:700 11px/1.35 Quicksand;color:#555}.notification-copy small{font:700 10px Quicksand;color:#888}.unread-dot{width:7px;height:7px;border-radius:50%;background:#7e9fe7;border:1px solid #171717}.chat-sheet{max-height:88vh}.chat-meta{display:flex;gap:8px;margin:-8px 0 14px}.chat-meta span{border:1.5px solid #171717;border-radius:999px;background:#fff;padding:6px 9px;font:800 10px Quicksand;color:#666}.chat-list{display:grid;gap:10px;max-height:48vh;overflow:auto;padding:3px 2px 12px}.chat-message{display:flex;align-items:flex-end;gap:7px;max-width:88%}.chat-message.mine{margin-left:auto;flex-direction:row-reverse}.chat-avatar{width:30px;height:30px;flex:0 0 30px;border:1.5px solid #171717;border-radius:50%;background:#ffe5d4;display:grid;place-items:center;font:900 10px Quicksand}.chat-bubble{border:2px solid #171717;border-radius:16px 16px 16px 5px;background:#fff;padding:8px 10px;min-width:0}.chat-message.mine .chat-bubble{border-radius:16px 16px 5px 16px;background:#e9e5ff}.chat-bubble p{margin:0;font:700 12px/1.35 Quicksand;overflow-wrap:anywhere}.chat-bubble small{display:block;margin-top:4px;color:#888;font:700 9px Quicksand}.chat-composer{display:grid;grid-template-columns:minmax(0,1fr) 46px;gap:8px;margin-top:4px}.chat-composer input{height:46px!important;min-width:0}.chat-send{width:46px;height:46px;border:2px solid #171717;border-radius:15px;background:#171717;color:#fff;display:grid;place-items:center;box-shadow:-3px 4px 0 #a1a2a4}.chat-send:active{transform:translate(-1px,1px);box-shadow:-2px 2px 0 #a1a2a4}.rating-sheet{max-height:90vh}.rating-summary{display:flex;align-items:center;justify-content:space-between;gap:10px;margin:-6px 0 10px;padding:11px 12px;border:1.5px solid #171717;border-radius:15px;background:#fff;box-shadow:-3px 4px 0 #ddd}.rating-summary-copy{display:grid;gap:2px;min-width:0}.rating-summary-copy strong{font:900 13px Nunito}.rating-summary-copy span{font:700 10px Quicksand;color:#777;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.rating-progress{border:1.5px solid #171717;border-radius:999px;background:#e9e5ff;padding:6px 8px;font:900 9px Quicksand;white-space:nowrap}.rating-host-note{display:flex;align-items:center;gap:7px;margin:0 0 12px;padding:9px 10px;border:1.5px solid #171717;border-radius:13px;background:#ddf3e7;font:800 10px Quicksand;color:#4e6e59}.rating-list{display:grid;gap:10px;margin-bottom:14px}.rating-row{border:2px solid #171717;border-radius:18px;background:#fff;padding:11px;display:grid;gap:9px;box-shadow:-3px 4px 0 #ddd}.rating-row.rating-complete{background:#fafdfb}.rating-row-head{display:flex;align-items:center;justify-content:space-between;gap:8px}.rating-person{display:flex;align-items:center;gap:9px;min-width:0}.rating-person>span:last-child{display:grid;gap:2px;min-width:0}.rating-person strong{font:900 14px Nunito;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.rating-person small{font:700 10px Quicksand;color:#777}.rating-row-status{border:1.5px solid #171717;border-radius:999px;background:#f8f8f8;padding:5px 7px;font:900 8.5px Quicksand;white-space:nowrap}.rating-complete .rating-row-status{background:#ddf3e7}.rating-score{display:grid;grid-template-columns:minmax(0,1fr) 46px 46px;align-items:center;gap:7px;min-width:0;isolation:isolate}.rating-stepper{position:relative;z-index:3;display:flex;align-items:center;justify-content:center;width:46px;min-width:46px;height:46px;border:1.5px solid #171717;border-radius:12px;background:#fff;color:#171717;font:900 22px/1 Nunito;box-shadow:-3px 4px 0 #a1a2a4;pointer-events:auto;touch-action:manipulation;user-select:none;-webkit-user-select:none;-webkit-touch-callout:none;-webkit-tap-highlight-color:transparent;padding:0}.rating-stepper:active{transform:translate(-1px,1px);box-shadow:-2px 2px 0 #a1a2a4}.stars{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:5px;width:100%;min-width:0;height:40px;border-radius:11px}.star-choice{width:100%;min-width:0;height:40px;border:1.5px solid #171717;border-radius:10px;background:#fff;color:#aaa;display:grid;place-items:center;user-select:none;pointer-events:auto;-webkit-user-select:none;-webkit-touch-callout:none;-webkit-tap-highlight-color:transparent;touch-action:manipulation;padding:0;font:900 19px/1 Quicksand}.star-choice:disabled{opacity:1}.star-choice.filled{background:#ffe9bf;color:#171717}.star-choice.selected-star{box-shadow:-2px 2px 0 #a1a2a4}.star-choice:active{transform:translate(-1px,1px);box-shadow:-1px 2px 0 #a1a2a4}.rating-value{display:block;text-align:center;color:#777;font:800 10px Quicksand;white-space:nowrap;margin-top:-1px}.rating-toggles{display:grid;grid-template-columns:1fr 1fr;gap:7px}.rating-toggles button{border:1.5px solid #171717;border-radius:12px;background:#fff;padding:8px;font:800 10px Quicksand}.rating-toggles button.on{background:#ddf3e7}.profile-sport-grid{margin-bottom:10px}.profile-sport-grid button{border:2px solid #171717;border-radius:17px;background:#fff;padding:12px;display:flex;justify-content:space-between;align-items:center;font:900 12px Quicksand;box-shadow:-3px 4px 0 #ddd}.profile-sport-grid button.selected{background:#e9e5ff;box-shadow:-3px 4px 0 #a1a2a4}.profile-levels{margin-top:18px}.level-row{display:grid;gap:7px;padding:12px 0;border-top:1px solid #ddd}.level-row:first-child{border-top:0;padding-top:0}.level-row-head{display:flex;align-items:baseline;justify-content:space-between;gap:10px}.level-row-head strong{font:900 13px Nunito}.level-row-head span{color:#888;font:700 9.5px Quicksand}.profile-skill-list{padding:0;gap:7px}.profile-skill-list button{min-height:58px}.profile-skill-list button.selected-choice{background:#e9e5ff;box-shadow:-2px 3px 0 #a1a2a4}.setting-card{border:2px solid #171717;border-radius:17px;background:#fff;padding:13px;display:flex;align-items:center;justify-content:space-between;gap:10px;margin-bottom:13px;box-shadow:-3px 4px 0 #ddd}.setting-card>span:first-child{display:grid;gap:3px}.setting-card strong{font:900 12px Nunito}.setting-card small{font:700 11px Quicksand;color:#777}.setting-value{font:800 10px Quicksand;background:#ddf3e7;border:1.5px solid #171717;border-radius:999px;padding:6px 8px}.toggle-row{width:100%;border:0;border-bottom:1px solid #ddd;background:#fff;padding:14px 0;display:flex;align-items:center;justify-content:space-between;gap:12px;text-align:left}.toggle-row>span:first-child{display:grid;gap:3px}.toggle-row strong{font:900 13px Nunito}.toggle-row small{font:700 10px/1.3 Quicksand;color:#777}.toggle{width:46px;height:27px;border:2px solid #171717;border-radius:99px;background:#eee;padding:3px;display:flex;align-items:center;justify-content:flex-start;flex:0 0 auto}.toggle span{width:17px;height:17px;border-radius:50%;background:#fff;border:1.5px solid #171717;box-shadow:-1px 2px 0 #aaa}.toggle.on{background:#dcecff;justify-content:flex-end}.toggle.on span{box-shadow:none}.scrim{position:fixed;inset:0;background:rgba(0,0,0,.38);z-index:10000;display:flex;align-items:flex-end}.scrim-backdrop{position:absolute;inset:0;width:100%;height:100%;border:0;background:transparent;padding:0;cursor:default}.sheet{position:relative;z-index:10001;width:min(430px,100%);margin:0 auto;background:#fbfbfb;border:2px solid #171717;border-bottom:0;border-radius:27px 27px 0 0;padding:20px 16px 120px;max-height:92vh;overflow:auto}.sheet h2{margin:0;font:900 25px Nunito}.sheet-head{margin-bottom:20px}.sheet-note{margin:-8px 0 16px;color:#666;font:700 12px Quicksand}.sheet .form-field{position:relative;z-index:2;display:grid;gap:6px;margin-bottom:13px}.sheet .form-field>.field-label{font:800 11px Quicksand}.sheet input,.sheet textarea{position:relative;z-index:3;pointer-events:auto;touch-action:auto;border:2px solid #171717;border-radius:14px;background:#fff;padding:0 12px;outline:0;font:700 13px Quicksand}.sheet input{height:45px}.sheet textarea{padding-top:11px;resize:vertical;min-height:75px}.two{display:grid;grid-template-columns:1fr 1fr;gap:10px}.picker-row{align-items:start}.picker-field{display:grid;gap:6px;min-width:0}.picker-label{font:800 11px Quicksand;display:block}.picker-button{position:relative;z-index:3;cursor:pointer;height:58px;width:100%;border:2px solid #171717;border-radius:16px;background:#fff;padding:8px 10px;display:flex;align-items:center;gap:8px;text-align:left;color:#171717;font:800 11px Quicksand;box-shadow:-3px 4px 0 #ddd;touch-action:manipulation;pointer-events:auto}.picker-button:active{transform:translate(-1px,1px);box-shadow:-2px 2px 0 #ddd}.picker-button-copy{display:grid;gap:2px;min-width:0;flex:1}.picker-button-copy strong{font:900 13px Nunito;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.picker-button-copy small{font:700 9px Quicksand;color:#888;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.picker-button.placeholder .picker-button-copy strong{color:#777}.picker-popover{margin:-4px 0 14px;border:2px solid #171717;border-radius:19px;background:#fff;box-shadow:-5px 6px 0 #a1a2a4;position:relative;z-index:2;overflow:hidden}.calendar-popover{padding:14px}.calendar-head{display:grid;grid-template-columns:38px 1fr 38px;align-items:center;gap:8px;text-align:center;margin-bottom:12px}.calendar-head strong{font:900 15px Nunito;text-transform:capitalize}.calendar-nav{width:36px;height:36px;border:1.5px solid #171717;border-radius:12px;background:#f8f8f8;display:grid;place-items:center}.weekdays,.calendar-grid{display:grid;grid-template-columns:repeat(7,1fr);gap:5px}.weekdays{margin-bottom:5px}.weekdays span{text-align:center;color:#888;font:800 10px Quicksand;padding:5px 0}.calendar-grid button,.calendar-grid span{height:36px}.calendar-grid button{border:1.5px solid transparent;border-radius:11px;background:#fff;font:800 12px Quicksand}.calendar-grid button:hover:not(:disabled){border-color:#171717;background:#f7f7f7}.calendar-grid button.selected{background:#dcecff;border-color:#171717;box-shadow:-2px 2px 0 #a1a2a4}.calendar-grid button:disabled{color:#c5c5c5;cursor:not-allowed}.time-popover{padding:14px}.time-wheel{height:220px;display:grid;grid-template-columns:1fr 1fr 1fr;gap:7px;position:relative;overflow:hidden}.wheel-column{height:220px;overflow-y:auto;scroll-snap-type:y mandatory;scrollbar-width:none;-ms-overflow-style:none;overscroll-behavior:contain}.wheel-column::-webkit-scrollbar{display:none}.wheel-column button{display:block;width:100%;height:44px;border:0;background:transparent;color:#777;font:800 26px/44px Quicksand;scroll-snap-align:center;opacity:.32}.wheel-column button.active-wheel{color:#171717;opacity:1;font-size:28px}.period-wheel button{font-size:25px}.wheel-spacer{height:88px;pointer-events:none}.wheel-selection{position:absolute;left:0;right:0;top:88px;height:44px;border-top:1.5px solid rgba(23,23,23,.2);border-bottom:1.5px solid rgba(23,23,23,.2);pointer-events:none}.wheel-fade{position:absolute;left:0;right:0;height:76px;z-index:2;pointer-events:none}.wheel-fade.top{top:0;background:linear-gradient(#fff,rgba(255,255,255,0))}.wheel-fade.bottom{bottom:0;background:linear-gradient(rgba(255,255,255,0),#fff)}.wheel-done{width:100%;margin-top:12px;border:2px solid #171717;border-radius:14px;background:#171717;color:#fff;height:43px;font:900 12px Quicksand}.event-editor-sheet{max-height:92vh;padding-bottom:68px;scroll-padding-top:18px;scroll-padding-bottom:72px} .event-editor-sheet .sheet-head{position:sticky;top:-20px;z-index:12;margin:0 -16px 20px;padding:20px 16px 14px;background:linear-gradient(#fbfbfb 76%,rgba(251,251,251,0));backdrop-filter:blur(7px);-webkit-backdrop-filter:blur(7px)} .event-editor-sheet .sheet-head>div{min-width:0}.event-editor-sheet .sheet-head h2{font-size:26px}.event-editor-sheet .form-field{margin-bottom:16px}.event-editor-sheet .form-field>label,.event-editor-sheet .field-label,.event-editor-sheet .picker-label{font-size:10px;letter-spacing:.055em;text-transform:uppercase;color:#666}.event-editor-sheet .form-field>input,.event-editor-sheet .form-field>textarea{box-shadow:-2px 3px 0 #e1e1e1;transition:border-color 160ms ease,box-shadow 160ms ease,transform 160ms ease}.event-editor-sheet .form-field>input:focus,.event-editor-sheet .form-field>textarea:focus{border-color:#171717;box-shadow:-3px 4px 0 #bfc5d3;transform:translateY(-1px)}.event-editor-sheet .choice-button{min-height:58px;border:2px solid #171717;border-radius:16px;background:#fff;box-shadow:-3px 4px 0 #ddd}.event-editor-sheet .choice-button>span{min-width:0}.event-editor-sheet .choice-button strong{font:900 14px Nunito;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.event-editor-sheet .choice-button small{font:700 9.5px Quicksand;color:#888;display:block;margin-top:2px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.event-editor-sheet .choice-button:active{transform:translate(-1px,1px);box-shadow:-2px 2px 0 #ddd}.event-editor-sheet .picker-button{box-shadow:-3px 4px 0 #ddd}.event-editor-sheet .primary{position:sticky;bottom:-20px;z-index:11;margin-top:6px;box-shadow:0 -10px 18px rgba(251,251,251,.92),-5px 6px 0 #a1a2a4}.event-editor-sheet .form-hint{display:block;margin-top:-7px;color:#888;font:700 9.5px/1.35 Quicksand}.event-editor-sheet .choice-popover,.event-editor-sheet .picker-popover{box-shadow:-4px 5px 0 #a1a2a4}.event-editor-sheet .choice-grid,.event-editor-sheet .choice-list{gap:7px}.event-editor-sheet .event-type-choice,.event-editor-sheet .choice-list>button{min-height:48px}.event-editor-sheet textarea{line-height:1.35;padding-top:11px}.event-editor-sheet .sheet-head .round{flex:0 0 auto}
.events-sheet{max-height:88vh}.events-segment{display:grid;grid-template-columns:1fr 1fr;gap:7px;margin:-2px 0 14px;padding:4px;border:2px solid #171717;border-radius:15px;background:#eee}.events-segment button{border:0;border-radius:11px;background:transparent;padding:9px 8px;font:900 12px Quicksand;color:#777}.events-segment button.active{background:#fff;color:#171717;box-shadow:-2px 3px 0 #c8c8c8}.events-list{display:grid;gap:9px}.event-list-row{width:100%;display:grid;grid-template-columns:6px minmax(0,1fr) auto;align-items:center;gap:10px;text-align:left;border:2px solid #171717;border-radius:17px;background:#fff;padding:11px 10px 11px 0;box-shadow:-3px 4px 0 #ddd}.event-list-row:active{transform:translate(-1px,1px);box-shadow:-2px 2px 0 #ddd}.event-list-accent{width:6px;align-self:stretch;border-radius:0 8px 8px 0;background:#ddf3e7}.event-list-accent.blue{background:#dcecff}.event-list-accent.peach{background:#ffe5d4}.event-list-accent.lavender{background:#e9e5ff}.event-list-copy{display:grid;gap:3px;min-width:0}.event-list-copy strong{font:900 14px/1.15 Nunito;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.event-list-copy small{font:800 10px Quicksand;color:#666}.event-list-copy>span{font:700 10px/1.25 Quicksand;color:#888;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.event-list-side{display:grid;justify-items:end;gap:7px;align-items:center}.event-status-mini{border:1.5px solid #171717;border-radius:999px;background:#eef6ff;padding:5px 7px;font:900 8.5px Quicksand;white-space:nowrap}.event-status-mini.full{background:#ffe9bf}.event-status-mini.completed{background:#ddf3e7}.event-status-mini.cancelled{background:#ffe1e1}.toast{position:fixed;z-index:50;bottom:calc(178px + env(safe-area-inset-bottom));left:50%;transform:translateX(-50%);background:#171717;color:#fff;border-radius:999px;padding:10px 15px;font:800 11px Quicksand;white-space:nowrap}@media(max-width:360px){.detail-grid{grid-template-columns:1fr}.hero-row{align-items:flex-start}.detail-hero h1{font-size:28px}.players-panel{padding:15px}}
@media(min-width:431px){.app-shell{margin-top:12px;min-height:calc(100vh - 24px);border-radius:5px}}

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

.load-state{margin:4px 0 24px;display:grid;gap:8px;text-align:center;align-items:center;justify-items:center;min-height:150px}.load-state strong{font:900 17px Nunito,sans-serif}.load-state span{max-width:270px;color:#777;font:700 11px/1.45 Quicksand,sans-serif}.error-state .tiny{margin-top:2px}
.discovery-skeleton-list{display:grid;gap:12px;margin:0 0 22px}.event-skeleton{min-height:148px;padding:18px;border:2px solid #171717;border-radius:20px;background:#fff;box-shadow:-4px 5px 0 #d7d8da;display:grid;align-content:start;gap:10px;overflow:hidden}.skeleton-line,.skeleton-pill,.skeleton-avatar,.skeleton-action{display:block;background:linear-gradient(90deg,#f0f0f0 20%,#e7e7e7 35%,#f0f0f0 50%);background-size:200% 100%;animation:skeleton-shimmer 1.35s ease-in-out infinite;border-radius:999px}.skeleton-line{height:10px}.skeleton-line.wide{width:72%;height:15px}.skeleton-line.medium{width:52%}.skeleton-line.short{width:34%}.skeleton-footer{margin-top:auto;display:flex;gap:8px;justify-content:space-between}.skeleton-pill{width:90px;height:28px;border-radius:999px}.skeleton-pill.small{width:62px}.friend-skeleton-list{display:grid;gap:10px;margin:6px 0 18px}.friend-skeleton{min-height:70px;padding:12px;border:2px solid #171717;border-radius:18px;background:#fff;box-shadow:-3px 4px 0 #d7d8da;display:flex;align-items:center;gap:11px}.skeleton-avatar{width:42px;height:42px;border-radius:50%;flex:0 0 auto}.skeleton-copy{display:grid;gap:8px;flex:1;min-width:0}.skeleton-action{width:58px;height:28px;border-radius:999px;flex:0 0 auto}@keyframes skeleton-shimmer{0%{background-position:200% 0}100%{background-position:-50% 0}}
@media(prefers-reduced-motion:reduce){.skeleton-line,.skeleton-pill,.skeleton-avatar,.skeleton-action{animation:none}}

@media(max-width:370px){.choice-grid{gap:7px}.choice-grid button{padding-left:8px;padding-right:8px;font-size:10px}.choice-list button{grid-template-columns:32px minmax(0,1fr) 18px}.choice-option-icon{width:29px;height:29px}}
.event-discovery-tools{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:8px;align-items:stretch;margin-bottom:9px}.event-filter-button{min-width:84px;border:2px solid #171717;border-radius:16px;background:#fff;box-shadow:-3px 4px 0 #ddd;display:flex;align-items:center;justify-content:center;gap:6px;padding:0 10px;font:900 11px Quicksand}.event-filter-button.active{background:#e9e5ff}.event-filter-button b{min-width:19px;height:19px;border:1.5px solid #171717;border-radius:50%;display:grid;place-items:center;font:900 9px Nunito;background:#fff}.event-filter-button:active{transform:translate(-1px,1px);box-shadow:-2px 2px 0 #ddd}.event-filter-popover{border:2px solid #171717;border-radius:19px;background:#fff;box-shadow:-5px 6px 0 #a1a2a4;padding:14px;margin-bottom:16px;position:relative;z-index:24;overflow:hidden;transform-origin:50% 0}.event-filter-head{display:flex;align-items:flex-start;justify-content:space-between;gap:10px;margin-bottom:12px}.event-filter-head>div{display:grid;gap:2px}.event-filter-head strong{font:900 14px Nunito}.event-filter-head small{font:700 9.5px Quicksand;color:#777}.event-filter-section{display:grid;gap:7px;margin-top:11px}.event-filter-section>span{font:900 10px Quicksand;color:#777;text-transform:uppercase;letter-spacing:.07em}.event-filter-chips{display:flex;flex-wrap:wrap;gap:7px}.event-filter-chips button{border:1.5px solid #171717;border-radius:999px;background:#fbfbfb;padding:8px 10px;font:800 10px Quicksand;box-shadow:-2px 3px 0 #e1e1e1}.event-filter-chips button.chosen{background:#e9e5ff;box-shadow:-2px 3px 0 #a1a2a4}.event-filter-chips button:active{transform:translate(-1px,1px);box-shadow:-1px 2px 0 #e1e1e1}.selection-grid{display:grid;grid-template-columns:1fr 1fr;gap:9px}.home-filter-option{gap:8px}.home-filter-option .choice-check{font:900 14px Nunito}.home-filter-popover .sports-option.selected-choice{background:#e9e5ff}.home-filter-popover .esports-option.selected-choice{background:#f8dfe3}.event-type-choice.sport-option.selected-choice{background:#e9e5ff}.event-type-choice.esports-option.selected-choice{background:#f8dfe3;color:#a94d55}.event-type-choice.esports-option.selected-choice .choice-check{color:#a94d55}
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

  .sheet input,.sheet textarea{position:relative;z-index:3;pointer-events:auto;touch-action:auto;border:2px solid #171717;border-radius:14px;background:#fff;padding:0 12px;outline:0;font:700 13px Quicksand}.sheet input{height:45px}.sheet textarea{padding-top:11px;resize:vertical;min-height:75px}.form-hint{display:block;color:#888;font:700 9px Quicksand;margin-top:6px}.chat-avatar.blue{background:#dcecff}.chat-avatar.peach{background:#ffe5d4}.chat-avatar.lavender{background:#e9e5ff}.chat-avatar.mint{background:#ddf3e7}
  .request-summary{width:100%;border:0;background:transparent;padding:0;display:grid;grid-template-columns:34px minmax(0,1fr) 18px;align-items:center;gap:9px;text-align:left;color:#171717}
  .request-summary:active{opacity:.62}
  .request-summary-icon{width:34px;height:34px;border:1.5px solid #171717;border-radius:11px;background:#fff;display:grid;place-items:center}
  .request-summary-copy{display:grid;gap:3px;min-width:0}
  .request-summary-copy strong{font:900 14px Nunito;line-height:1.1}
  .request-summary-copy span{font:700 10px/1.25 Quicksand;color:#777}
  .request-person{border:0;background:transparent;padding:0;display:flex;align-items:center;gap:9px;min-width:0;text-align:left;flex:1}.request-person:active,.friend-main:active,.profile-trigger:active,.profile-link:active{opacity:.62}
  .profile-link{border:0;background:transparent;padding:0;color:#171717;font:inherit;font-weight:900;text-decoration:underline;text-decoration-thickness:1px;text-underline-offset:2px}.profile-trigger{border:0;background:transparent;padding:0;color:inherit;display:flex;align-items:center;gap:10px;text-align:left;width:100%}.profile-avatar-chip{width:31px;height:31px;border:2px solid #171717;border-radius:50%;display:grid;place-items:center;font:800 10px Quicksand;margin-right:-5px;box-shadow:none}.profile-avatar-chip.blue{background:#dcecff}.profile-avatar-chip.peach{background:#ffe5d4}.profile-avatar-chip.lavender{background:#e9e5ff}.profile-avatar-chip.mint{background:#ddf3e7}.player-profile-sheet{max-height:92vh}.player-profile-hero{display:grid;justify-items:center;gap:8px;text-align:center;padding:4px 0 8px}.player-profile-hero .profile-avatar{width:82px;height:82px;flex-basis:82px;font-size:27px}.player-profile-hero strong{font:900 19px Nunito}.player-profile-hero p{max-width:340px;margin:0;color:#666;font:700 11px/1.45 Quicksand}.profile-status{border:1.5px solid #171717;border-radius:999px;padding:5px 9px;background:#ddf3e7;font:800 10px Quicksand}.profile-stat-grid{margin-top:18px}.profile-sport-list{display:grid;gap:0}.profile-sport-list>div{display:flex;align-items:center;justify-content:space-between;padding:11px 0;border-top:1px solid #ddd}.profile-sport-list>div:first-child{border-top:0}.profile-sport-list strong{font:900 13px Nunito}.profile-sport-list span{font:800 10px Quicksand;color:#777}.chat-avatar-button{border:0;background:transparent;padding:0;display:block;flex:0 0 auto}.chat-avatar-button:active{opacity:.62}.chat-sender-link{display:inline-block;margin:0 0 2px;font-size:11px}.rating-person{min-width:0}.rating-person .friend-copy{min-width:0}.host-line .profile-link{font:900 12px Quicksand}.player-profile-sheet .panel{margin-top:4px}




  /* Motion system: restrained, spring-like-feeling transitions that preserve Huddl's geometry. */
  :global(button), :global(input), :global(textarea), :global(select),
  :global(a), .choice-button, .picker-button, .setting-card, .notification-row,
  .event-list-row, .request-row, .friend-row, .chat-event-row, .rating-row,
  .panel, .stat-grid > div, .search, .request, .detail-grid > div {
    transition: transform 160ms cubic-bezier(.22,.61,.36,1),
                box-shadow 160ms cubic-bezier(.22,.61,.36,1),
                background-color 160ms ease,
                border-color 160ms ease,
                opacity 160ms ease;
  }
  :global(button:not(:disabled):not(.scrim-backdrop)):hover,
  .setting-card:hover, .notification-row:hover, .event-list-row:hover,
  .chat-event-row:hover, .rating-row:hover, .friend-row:hover {
    transform: translateY(-1px);
  }
  :global(button:not(:disabled)):active {
    transition-duration: 70ms;
  }
  .scrim {
    will-change: opacity;
    backdrop-filter: blur(1.5px);
    -webkit-backdrop-filter: blur(1.5px);
  }
  .sheet {
    will-change: transform, opacity;
    transform-origin: 50% 100%;
  }
  .choice-popover, .home-filter-popover, .picker-popover {
    will-change: transform, opacity;
    transform-origin: 50% 0;
  }
  .chat-surface-inner {
    will-change: transform, opacity;
  }
  .notification-row, .event-list-row, .friend-row, .request-row {
    will-change: transform;
  }
  .create, .chat-fab {
    will-change: transform, opacity;
  }
  @media (prefers-reduced-motion: reduce) {
    :global(*), :global(*::before), :global(*::after) {
      scroll-behavior: auto !important;
      animation-duration: 0.01ms !important;
      animation-iteration-count: 1 !important;
      transition-duration: 0.01ms !important;
    }
  }


/* Home discovery UI alignment polish */
.home-filters{
  display:grid;
  grid-template-columns:repeat(3,minmax(0,1fr));
  gap:8px;
  width:100%;
  margin-bottom:18px;
  padding:0 1px 2px;
}
.home-filters button{
  width:100%;
  min-width:0;
  min-height:42px;
  padding:9px 8px;
  display:flex;
  align-items:center;
  justify-content:center;
  gap:5px;
  text-align:center;
}
.home-filters .esports-filter-button,.home-filters .sports-filter-button{
  border-width:1.5px!important;
}
.home-filters .esports-filter-button span,.home-filters .sports-filter-button span{
  font-size:12px;
  line-height:1;
  transform:translateY(-1px);
}
.home-filter-popover{
  margin:-6px 1px 18px;
  padding:11px;
  gap:8px;
}
.home-filter-popover button.home-filter-option{
  min-height:44px;
  padding:9px 10px;
}
.home-sports-popover,.home-esports-popover{
  grid-template-columns:repeat(2,minmax(0,1fr));
}
.home-filter-empty{
  grid-column:1 / -1;
}
.event-discovery-tools{
  grid-template-columns:minmax(0,1fr) 86px;
  gap:8px;
  margin-bottom:16px;
}
.event-search{
  width:100%;
  margin:0;
}
.event-filter-button{
  width:86px;
  min-width:86px;
  min-height:48px;
  padding:0 8px;
}
.event-filter-popover{
  margin:-6px 0 18px;
  padding:14px 13px 13px;
}
.event-filter-section{
  margin-top:12px;
  padding-top:12px;
  border-top:1px solid #e6e6e6;
}
.event-filter-section:first-of-type{
  margin-top:0;
  padding-top:0;
  border-top:0;
}
.event-filter-chips{
  display:grid;
  grid-template-columns:repeat(2,minmax(0,1fr));
  gap:7px;
}
.event-filter-chips button{
  width:100%;
  min-height:36px;
  padding:8px 8px;
  display:flex;
  align-items:center;
  justify-content:center;
  text-align:center;
}
.event-filter-section:nth-of-type(2) .event-filter-chips{
  grid-template-columns:repeat(3,minmax(0,1fr));
}
.event-filter-section:nth-of-type(3) .event-filter-chips{
  grid-template-columns:repeat(2,minmax(0,1fr));
}
.discovery-head{
  margin-bottom:13px;
}
.discovery-sort{
  min-height:34px;
  align-items:stretch;
}
.discovery-sort button{
  min-width:59px;
  min-height:28px;
  display:grid;
  place-items:center;
}
.home-empty-state{
  margin-top:2px;
}
@media(max-width:370px){
  .home-filters{gap:7px}
  .home-filters button{padding-inline:5px;font-size:11px}
  .event-discovery-tools{grid-template-columns:minmax(0,1fr) 80px}
  .event-filter-button{width:80px;min-width:80px}
  .event-filter-chips button{font-size:9px;padding-inline:6px}
}


/* Profile page polish */
.profile-screen{padding-top:22px}.profile-hero{border:2px solid #171717;border-radius:25px;background:#ffe5d4;padding:17px;box-shadow:-5px 6px 0 #a1a2a4;margin-bottom:18px}.profile-hero-top{display:flex;align-items:center;justify-content:space-between;gap:10px}.profile-hero-top .profile-avatar{width:66px;height:66px;flex-basis:66px;font-size:23px}.profile-identity{display:grid;gap:2px;margin-top:14px}.profile-identity .eyebrow{margin-bottom:2px}.profile-identity h1{margin:0;font:900 29px/1.05 Nunito;letter-spacing:-.03em;overflow-wrap:anywhere}.profile-handle{margin:0;color:#666;font:800 11px Quicksand}.profile-hero .bio{margin:13px 0 0;max-width:330px;color:#555;font:700 12px/1.45 Quicksand}.profile-sports-panel{margin-bottom:18px}.profile-section-title{display:grid;gap:3px}.profile-section-title span{color:#888;font:700 9.5px Quicksand}.profile-sports-list{border-top:1px solid #ddd}.profile-sports-list .sport-row{min-height:49px}.sport-level{border:1.5px solid #171717;border-radius:999px;background:#e9e5ff;padding:5px 8px!important;color:#5f5f5f!important;font:900 9px Quicksand!important;white-space:nowrap}.profile-inline-state{margin-top:4px;box-shadow:none}.profile-settings-block{margin-bottom:14px}.profile-settings-label{margin:0 0 8px 3px;color:#888;font:900 9px Quicksand;letter-spacing:.09em}.profile-settings{border-radius:22px}.profile-settings button{min-height:67px;padding:11px 13px;gap:10px}.setting-leading{display:flex;align-items:center;gap:10px;min-width:0;text-align:left}.setting-leading>span:last-child{display:grid;gap:2px;min-width:0}.setting-leading strong{font:900 13px Nunito}.setting-leading small{color:#888;font:700 9.5px/1.25 Quicksand;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:250px}.setting-icon{width:36px;height:36px;border:1.5px solid #171717;border-radius:12px;display:grid;place-items:center;flex:0 0 36px;background:#fff}.setting-icon.calendar{background:#dcecff}.setting-icon.account{background:#ffe5d4}.setting-icon.preferences{background:#e9e5ff}.setting-icon.notifications{background:#ddf3e7}.profile-settings .setting-badge{margin-left:auto;margin-right:2px}.profile-signout{width:100%;border:2px solid #171717;border-radius:19px;background:#fff;padding:13px 14px;box-shadow:-4px 5px 0 #a1a2a4;display:flex;align-items:center;justify-content:space-between;text-align:left}.profile-signout>span{display:grid;gap:2px}.profile-signout strong{font:900 13px Nunito}.profile-signout small{color:#888;font:700 10px Quicksand}.profile-signout:active{transform:translate(-1px,1px);box-shadow:-2px 3px 0 #a1a2a4}


/* Notifications + chat UI polish */
.notification-sheet{max-height:88vh}
.notification-sheet .sheet-head{margin-bottom:15px}
.notification-list{gap:9px;margin-bottom:13px}
.notification-row{position:relative;grid-template-columns:42px minmax(0,1fr) 9px;gap:11px;padding:11px 12px;border-radius:18px;transition:transform 140ms ease,box-shadow 140ms ease,background 140ms ease}
.notification-row:hover{transform:translate(0,-1px);box-shadow:-3px 4px 0 #ddd}
.notification-row:active{transform:translate(-1px,1px);box-shadow:-1px 2px 0 #ddd}
.notification-row.unread{background:#eef6ff}
.notification-icon{width:42px;height:42px;border-radius:14px;background:#fbfbfb;box-shadow:-2px 3px 0 #e1e1e1}
.notification-copy{gap:4px;padding-right:2px}
.notification-copy strong{font-size:13px;line-height:1.1}
.notification-copy span{font-size:10.5px;line-height:1.4}
.notification-copy small{font-size:9px}
.unread-dot{width:8px;height:8px;justify-self:end}
.notification-sheet>.secondary{margin-top:2px}

.chat-sheet{max-height:90vh;padding-bottom:112px}
.chat-detail-head{display:grid;grid-template-columns:43px minmax(0,1fr) 43px;align-items:center;gap:9px}
.chat-detail-head>div:nth-child(2){min-width:0}
.chat-detail-head h2{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.chat-back{margin:0}
.chat-meta{margin:-9px 0 12px;gap:7px;overflow-x:auto;scrollbar-width:none}
.chat-meta::-webkit-scrollbar{display:none}
.chat-meta span{padding:6px 9px;font-size:9.5px;white-space:nowrap}
.chat-list{max-height:47vh;gap:12px;padding:4px 1px 14px;scrollbar-width:thin}
.chat-message{max-width:92%;gap:7px;align-items:flex-end}
.chat-avatar-button{border:0;background:transparent;padding:0;width:30px;height:30px;flex:0 0 30px}
.chat-avatar{width:30px;height:30px}
.chat-bubble{max-width:min(82vw,315px);padding:9px 11px;border-radius:17px 17px 17px 6px;box-shadow:-2px 3px 0 #ddd}
.chat-message.mine .chat-bubble{border-radius:17px 17px 6px 17px;box-shadow:-2px 3px 0 #c8c1e4}
.chat-sender-link{display:block;margin:0 0 2px;text-align:left;font:900 10px Nunito;color:#555;border:0;background:transparent;padding:0}
.chat-bubble p{font-size:11.5px;line-height:1.4}
.chat-bubble small{font-size:8.5px;margin-top:5px}
.chat-empty{border:2px dashed #aaa;border-radius:17px;padding:22px 14px;text-align:center;background:#fff;color:#777;font:800 11px Quicksand}
.chat-composer{position:sticky;bottom:0;z-index:4;padding-top:9px;background:linear-gradient(#fbfbfb 0%,#fbfbfb 72%,rgba(251,251,251,.96) 100%);grid-template-columns:minmax(0,1fr) 48px;gap:8px}
.chat-composer input{border-radius:16px!important;box-shadow:-3px 4px 0 #ddd}
.chat-send{width:48px;height:48px;border-radius:16px;box-shadow:-3px 4px 0 #a1a2a4}
.chat-hub-list{display:grid;gap:9px}
.chat-event-row{width:100%;display:grid;grid-template-columns:43px minmax(0,1fr) 18px;align-items:center;gap:10px;text-align:left;border:2px solid #171717;border-radius:18px;background:#fff;padding:11px 12px;box-shadow:-3px 4px 0 #ddd;transition:transform 140ms ease,box-shadow 140ms ease}
.chat-event-row:hover{transform:translate(0,-1px);box-shadow:-4px 5px 0 #cfcfcf}
.chat-event-row:active{transform:translate(-1px,1px);box-shadow:-1px 2px 0 #ddd}
.chat-event-icon{width:43px;height:43px;border:1.5px solid #171717;border-radius:14px;background:#e9e5ff;display:grid;place-items:center}
.chat-event-copy{display:grid;gap:3px;min-width:0}
.chat-event-copy strong{font:900 14px/1.15 Nunito;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.chat-event-copy small{font:700 9.5px Quicksand;color:#777;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
@media(max-width:360px){
  .notification-row{grid-template-columns:39px minmax(0,1fr) 8px;padding:10px}
  .notification-icon{width:39px;height:39px}
  .chat-bubble{max-width:76vw}
  .chat-sheet{padding-left:13px;padding-right:13px}
}
@media(prefers-reduced-motion:reduce){
  .notification-row,.chat-event-row{transition:none}
}
</style>
