export const sports = ['All', 'Football', 'Volleyball', 'Tennis', 'Basketball', 'Badminton', 'Chess', 'Pool', 'Table Tennis', 'Cricket', 'Futsal', 'Squash', 'Box Cricket'];

export const events = [
  { id: 1, sport: 'Football', title: 'Friday Night Football', date: 'Fri, 7:30 PM', dateValue: '2026-10-02', time: '19:30', location: 'City Sports Arena', host: 'Arjun', members: 5, capacity: 7, skill: 'Intermediate', color: 'blue', description: 'A casual 7-a-side game. Bring boots, water and be ready to rotate.' },
  { id: 2, sport: 'Badminton', title: 'Sunday Badminton', date: 'Sun, 10:00 AM', dateValue: '2026-10-04', time: '10:00', location: 'Smash Courts', host: 'Meera', members: 3, capacity: 4, skill: 'Beginner', color: 'peach', description: 'Doubles session with short games and rotating partners.' },
  { id: 3, sport: 'Basketball', title: 'Half Court Hoops', date: 'Sat, 5:00 PM', dateValue: '2026-10-03', time: '17:00', location: 'Campus Courts', host: 'Rohan', members: 4, capacity: 6, skill: 'Intermediate', color: 'lavender', description: 'Half-court pickup. First to 11, win by 2.' }
];

export const friends = [
  { id: 1, name: 'Arjun Mehta', handle: '@arjun', sports: 'Football · Basketball', status: 'online', color: 'peach' },
  { id: 2, name: 'Meera Shah', handle: '@meera', sports: 'Badminton · Tennis', status: '2h ago', color: 'lavender' },
  { id: 3, name: 'Rohan Das', handle: '@rohan', sports: 'Basketball · Football', status: 'yesterday', color: 'blue' },
  { id: 4, name: 'Ishita Rao', handle: '@ishita', sports: 'Badminton', status: 'online', color: 'mint' }
];

export const stats = {
  games: 24,
  hosted: 8,
  rating: 4.7,
  attendance: 92,
  sports: [
    { name: 'Football', games: 12 },
    { name: 'Badminton', games: 7 },
    { name: 'Basketball', games: 5 }
  ]
};

export const profile = {
  name: 'Sanjay Shashibushan',
  handle: '@sanjay',
  bio: 'Always down for a game.',
  sports: ['Football', 'Badminton', 'Basketball'],
  skills: ['Intermediate', 'Beginner', 'Intermediate']
};
