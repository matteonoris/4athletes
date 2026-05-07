
import React, { useState, useEffect } from 'react';
import { Users } from 'lucide-react';
import BottomNav from './components/BottomNav';
import Home from './pages/Home';
import Analytics from './pages/Analytics';
import Teams from './pages/Teams';
import Profile from './pages/Profile';
import AddTraining from './pages/AddTraining';
import ActivitySelect from './pages/ActivitySelect';
import TeamDetails from './pages/TeamDetails';
import ExerciseDetails from './pages/ExerciseDetails';
import JumpDetails from './pages/JumpDetails';
import BodyMetrics from './pages/BodyMetrics';
import AllSessions from './pages/AllSessions';
import AllBodyMetrics from './pages/AllBodyMetrics';
import CreateTeam from './pages/CreateTeam';
import CoachDashboard from './pages/CoachDashboard';
import CoachEventDetails from './pages/CoachEventDetails';
import Auth from './pages/Auth';
import { ViewState, UserProfile, TrainingSession, Team, BodyMetricLog, PRLog, JumpLog, JumpType, CalendarEvent } from './types';

const INITIAL_SESSIONS: TrainingSession[] = [
  {
    id: 'mock-1',
    sportId: 'alpine_skiing',
    date: new Date().toISOString().split('T')[0],
    startTime: '08:30',
    endTime: '11:45',
    duration: '3h 15m',
    effort: 8,
    details: {
      specialties: ['GS'],
      gatedSkiing: { changes: '40', laps: '5' }, 
      freeSkiing: { changes: '12', laps: '3' },
      snowCondition: 'hard',
      weatherCondition: 'sunny'
    }
  }
];

const INITIAL_TEAMS: Team[] = [
  {
    id: 't1',
    name: 'Alpine Elite Squad',
    members: 8,
    category: 'Skiing',
    inviteCode: 'ALPH12',
    image: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAD0JyqaYOUXZO3wyUmUbN3-WJd-2bq6GGaXRZcigNXV3tTFbBhH1_88tOz9qeHYORh5KJJGti1-WcCulR1ILafKnCRDW2-81Gn5S4f5UdTyIJfLD52wp5qHz-nMKrC595uqv6c0xSShLRGUPQhCKelPUlHoKGH5uxf_tsTxrJPzTMN-ISNo0S2o8cMSFxn7kK14rqLX0dGqfZruAlGaC8iyrAelKZbrvEtF_-dmfVcJEX0-wd3OY0zyYfL9HvpV0F111ZkG1jEMv3U'
  }
];

// Mock Athletes for Init
const MOCK_ATHLETES = [
    { id: '1', name: 'Sarah Jenkins' },
    { id: '2', name: 'Mike Thompson' },
    { id: '3', name: 'Alex Rivera' },
    { id: '4', name: 'Jessica Lee' },
    { id: '5', name: 'Davide Rossi' },
];

const INITIAL_COACH_EVENTS: CalendarEvent[] = [
    {
      id: 'e1',
      teamId: 't1',
      type: 'training',
      title: 'Technical Slalom Drills',
      date: new Date().toISOString().split('T')[0],
      startTime: '09:00',
      endTime: '11:00',
      location: 'Main Slope',
      technicalDetails: {
          snowCondition: 'hard',
          weatherCondition: 'sunny',
          specialties: ['SL'],
          freeSkiing: { laps: '4', changes: '12' },
          gatedSkiing: { laps: '6', changes: '45' }
      },
      attendees: MOCK_ATHLETES.map(a => ({ ...a, isPresent: true }))
    }
];

// Global pool of "discoverable" teams for joining demo
const ALL_AVAILABLE_TEAMS: Team[] = [
    ...INITIAL_TEAMS,
    { id: 't2', name: 'Powerlifting Rome', members: 15, category: 'Fitness', inviteCode: 'ROME88', image: 'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=400' },
    { id: 't3', name: 'Crossfit Milano', members: 42, category: 'CrossFit', inviteCode: 'MIL400', image: 'https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5?w=400' }
];

function App() {
  const [currentView, setView] = useState<ViewState>(() => {
    const isLoggedIn = localStorage.getItem('isLoggedIn') === 'true';
    return isLoggedIn ? 'home' : 'auth';
  });

  const [selectedSportId, setSelectedSportId] = useState<string>('weightlifting');
  const [editingSession, setEditingSession] = useState<TrainingSession | undefined>(undefined);
  const [selectedTeam, setSelectedTeam] = useState<Team | undefined>(INITIAL_TEAMS[0]);
  
  // Navigation State
  const [selectedExerciseId, setSelectedExerciseId] = useState<string>('back_squat');
  const [selectedJumpType, setSelectedJumpType] = useState<JumpType>('cm_jump');

  // Coach Specific State
  const [coachEvents, setCoachEvents] = useState<CalendarEvent[]>(INITIAL_COACH_EVENTS);
  const [selectedCoachEventId, setSelectedCoachEventId] = useState<string | null>(null);
  const [newCoachEventDate, setNewCoachEventDate] = useState<string | null>(null); // For creating new event on specific date

  // State to control which tab opens in Body Metrics (Weight or Height)
  const [bodyMetricsTab, setBodyMetricsTab] = useState<'weight' | 'height'>('weight');

  const [userProfile, setUserProfile] = useState<UserProfile>(() => {
    const saved = localStorage.getItem('userProfile');
    return saved ? JSON.parse(saved) : {
      firstName: 'Alex',
      lastName: 'Skier',
      email: 'alex.skier@example.com',
      birthDate: '2010-03-12', // Set to younger for demo height chart
      role: 'athlete',
      weight: 65.5,
      height: 172,
      maxHr: 195,
      unitSystem: 'metric',
      language: 'it',
      notificationsEnabled: true, 
      connectedDevices: [], // Default empty
      avatarUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCGLG8aXjW9zR3nKtXEiuVED9z2IU0sGhlSpQV0oBelFGkfejq2KPYuBbAPC_aIEWnZAt4f2JCfBZPvxufvEOhW8DWmRhWmWtq_1fU2OcLle1YvcUm8oTf3a7gS1bKXRJVS-loibPS29edn3jfmKMEDigbKu-OruzHSO7MnJItXK2_kCHc-hi5pgjeGy8yRDt_h2yVUzz5XInPtZ2_UsoXiMil8UKZVMZg0y2DyRGqbHr-YDeWjOMZ0Dp9R76McjxXwH8ciUummSiYs',
      oneRepMax: { 
          'back_squat': 145, 
          'bench_press': 105,
          'deadlift': 180,
          'clean_and_jerk': 95
      }
    };
  });

  // PR Logs History
  const [prLogs, setPrLogs] = useState<PRLog[]>(() => {
      const saved = localStorage.getItem('prLogs');
      if (saved) return JSON.parse(saved);

      // Generate initial Mock History for charts
      const logs: PRLog[] = [
          { id: '1', exerciseId: 'back_squat', date: '2023-08-10', weight: 130 },
          { id: '2', exerciseId: 'back_squat', date: '2023-09-15', weight: 135 },
          { id: '3', exerciseId: 'back_squat', date: '2023-10-20', weight: 140 },
          { id: '4', exerciseId: 'back_squat', date: '2023-11-05', weight: 145 }, // Current
          { id: '5', exerciseId: 'bench_press', date: '2023-09-01', weight: 95 },
          { id: '6', exerciseId: 'bench_press', date: '2023-10-12', weight: 100 },
          { id: '7', exerciseId: 'bench_press', date: '2023-11-01', weight: 105 },
          { id: '8', exerciseId: 'deadlift', date: '2023-07-01', weight: 160 },
          { id: '9', exerciseId: 'deadlift', date: '2023-09-01', weight: 170 },
          { id: '10', exerciseId: 'deadlift', date: '2023-10-15', weight: 180 },
      ];
      return logs;
  });

  // Jump Logs
  const [jumpLogs, setJumpLogs] = useState<JumpLog[]>(() => {
    const saved = localStorage.getItem('jumpLogs');
    if (saved) return JSON.parse(saved);

    // Initial Mock Data
    return [
      { id: 'j1', type: 'squat_jump', date: '2023-09-10', value: 40 },
      { id: 'j2', type: 'squat_jump', date: '2023-10-12', value: 42 },
      { id: 'j3', type: 'cm_jump', date: '2023-09-10', value: 45 },
      { id: 'j4', type: 'cm_jump', date: '2023-10-12', value: 48 },
      { id: 'j5', type: 'drop_jump', date: '2023-10-01', value: 35 },
      { id: 'j6', type: '45s_jump', date: '2023-10-01', value: 50 },
      { id: 'j7', type: '45s_jump', date: '2023-11-01', value: 52 },
      { id: 'j8', type: 'single_leg_left', date: '2023-10-10', value: 28 },
      { id: 'j9', type: 'single_leg_right', date: '2023-10-10', value: 26 },
    ];
  });

  // Mock History Data
  const [bodyLogs, setBodyLogs] = useState<BodyMetricLog[]>(() => {
     const saved = localStorage.getItem('bodyLogs');
     if (saved) return JSON.parse(saved);
     
     // Generate some initial data
     const logs: BodyMetricLog[] = [];
     const today = new Date();
     
     // Weight History
     for(let i=5; i>=0; i--) {
        const d = new Date(today);
        d.setMonth(d.getMonth() - i);
        logs.push({
            id: `w-${i}`,
            date: d.toISOString().split('T')[0],
            type: 'weight',
            value: 65.5 - (i * 0.3) + (Math.random() * 0.5) // Slight fluctuation
        });
     }

     // Height History
     for(let i=5; i>=0; i--) {
        const d = new Date(today);
        d.setMonth(d.getMonth() - i);
        logs.push({
            id: `h-${i}`,
            date: d.toISOString().split('T')[0],
            type: 'height',
            value: 172 - (i * 0.2) // Growing
        });
     }
     return logs;
  });

  const [sessions, setSessions] = useState<TrainingSession[]>(INITIAL_SESSIONS);
  const [teams, setTeams] = useState<Team[]>(INITIAL_TEAMS);

  useEffect(() => {
    localStorage.setItem('userProfile', JSON.stringify(userProfile));
  }, [userProfile]);

  useEffect(() => {
    localStorage.setItem('bodyLogs', JSON.stringify(bodyLogs));
  }, [bodyLogs]);

  useEffect(() => {
    localStorage.setItem('prLogs', JSON.stringify(prLogs));
  }, [prLogs]);

  useEffect(() => {
    localStorage.setItem('jumpLogs', JSON.stringify(jumpLogs));
  }, [jumpLogs]);

  // --- NOTIFICATION & FIRST LAUNCH LOGIC ---
  useEffect(() => {
    // 1. Check for first launch to request permissions
    const hasOpenedBefore = localStorage.getItem('hasOpenedBefore');
    if (!hasOpenedBefore) {
        if ('Notification' in window && Notification.permission !== 'granted' && Notification.permission !== 'denied') {
             // Request permission on first launch
             Notification.requestPermission().then(permission => {
                 if (permission === 'granted') {
                     new Notification("Benvenuto in 4Athletes!", {
                         body: "Ti invieremo promemoria per i tuoi allenamenti.",
                         icon: "/icon.png" // Fallback icon path
                     });
                 }
             });
        }
        localStorage.setItem('hasOpenedBefore', 'true');
    }

    // 2. Scheduled Check for 20:00 Reminder
    const checkNotification = () => {
        if (!userProfile.notificationsEnabled) return;
        if (!('Notification' in window) || Notification.permission !== 'granted') return;

        const now = new Date();
        const currentHour = now.getHours();
        const todayString = now.toISOString().split('T')[0];

        // Check if it is 20:00 (or slightly after, but only trigger once a day)
        const lastNotificationDate = localStorage.getItem('lastNotificationDate');

        // Logic: If it's 20:00 or later, and we haven't notified today
        if (currentHour >= 20 && lastNotificationDate !== todayString) {
            
            // Check if user has logged training today
            const hasTrainedToday = sessions.some(session => session.date === todayString);

            if (!hasTrainedToday) {
                // Send Notification
                try {
                    new Notification("Non dimenticare di allenarti!", {
                        body: "Non hai ancora registrato un allenamento oggi. Inseriscilo ora!",
                        requireInteraction: true, // Heads-up / Stickier on some systems
                        tag: 'daily-reminder'
                    });
                    // Mark as notified for today
                    localStorage.setItem('lastNotificationDate', todayString);
                } catch (e) {
                    console.error("Notification failed", e);
                }
            } else {
                // If they trained, we don't need to notify, but let's mark as "done" for the logic so we don't keep checking
                localStorage.setItem('lastNotificationDate', todayString);
            }
        }
    };

    // Run check every minute
    const intervalId = setInterval(checkNotification, 60000);
    
    // Run once on mount to check immediately if user opens app after 20:00
    checkNotification();

    return () => clearInterval(intervalId);
  }, [sessions, userProfile.notificationsEnabled]);


  const handleLogin = () => {
    localStorage.setItem('isLoggedIn', 'true');
    setView('home');
  };

  const handleRegister = (profile: UserProfile) => {
    setUserProfile(profile);
    localStorage.setItem('isLoggedIn', 'true');
    setView('home');
  };

  const handleLogout = () => {
    localStorage.removeItem('isLoggedIn');
    setView('auth');
  };

  const handleSaveProfile = (updatedProfile: UserProfile) => {
    setUserProfile(updatedProfile);
    if (userProfile.role === 'athlete') {
        setView('home');
    }
    // If Coach, CoachDashboard handles internal state, so no setView needed here necessarily, 
    // but the state update triggers re-render.
  };

  // Called when saving from BodyMetrics page
  const handleSaveBodyLog = (val: number, date: string, type: 'weight' | 'height') => {
    const newLog: BodyMetricLog = {
        id: Date.now().toString(),
        date,
        type,
        value: val
    };
    
    // Add to logs
    setBodyLogs(prev => [...prev, newLog].sort((a,b) => new Date(a.date).getTime() - new Date(b.date).getTime()));

    // Update current profile stats
    if (type === 'weight') {
        setUserProfile(prev => ({ ...prev, weight: val }));
    } else {
        setUserProfile(prev => ({ ...prev, height: val }));
    }
  };

  const handleUpdateBodyLog = (id: string, newVal: number) => {
      setBodyLogs(prev => prev.map(log => log.id === id ? { ...log, value: newVal } : log));
      // Optionally update profile if it's the most recent log, but simple approach is fine for now
  };

  const handleDeleteBodyLog = (id: string) => {
      setBodyLogs(prev => prev.filter(log => log.id !== id));
  };

  // --- PR Handlers ---
  const handleAddPR = (log: PRLog) => {
      setPrLogs(prev => [...prev, log].sort((a,b) => new Date(a.date).getTime() - new Date(b.date).getTime()));
      
      // Update User Profile Max if this new log is higher than existing
      const currentMax = userProfile.oneRepMax?.[log.exerciseId] || 0;
      if (log.weight > currentMax) {
          setUserProfile(prev => ({
              ...prev,
              oneRepMax: {
                  ...prev.oneRepMax,
                  [log.exerciseId]: log.weight
              }
          }));
      }
  };

  const handleDeletePR = (id: string) => {
      setPrLogs(prev => prev.filter(l => l.id !== id));
  };

  // --- Jump Handlers ---
  const handleAddJump = (log: JumpLog) => {
    setJumpLogs(prev => [...prev, log].sort((a,b) => new Date(a.date).getTime() - new Date(b.date).getTime()));
  };

  const handleDeleteJump = (id: string) => {
    setJumpLogs(prev => prev.filter(l => l.id !== id));
  };

  const handleSportSelect = (sportId: string) => {
    setSelectedSportId(sportId);
    setEditingSession(undefined);
    setView('add-training');
  };

  const handleSessionEdit = (sessionId: string) => {
    const sessionToEdit = sessions.find(s => s.id === sessionId);
    if (sessionToEdit) {
      setEditingSession(sessionToEdit);
      setSelectedSportId(sessionToEdit.sportId);
      setView('add-training');
    }
  };

  const handleSaveSession = (sessionData: TrainingSession) => {
    setSessions(prev => {
      const exists = prev.find(s => s.id === sessionData.id);
      if (exists) return prev.map(s => s.id === sessionData.id ? sessionData : s);
      return [sessionData, ...prev];
    });
    setEditingSession(undefined);
    setView('home');
  };

  // --- COACH SYNC LOGIC ---
  const handleCoachSync = (event: CalendarEvent) => {
      if (event.type !== 'training' || !event.attendees) return;

      const calculateDuration = (start: string, end: string) => {
        const [startH, startM] = start.split(':').map(Number);
        const [endH, endM] = end.split(':').map(Number);
        let diffM = (endH * 60 + endM) - (startH * 60 + startM);
        if (diffM < 0) diffM += 24 * 60;
        const h = Math.floor(diffM / 60);
        const m = diffM % 60;
        return `${h}h ${m}m`;
      };

      const newSession: TrainingSession = {
          id: `sync-${event.id}`,
          eventId: event.id,
          sportId: 'alpine_skiing', 
          date: event.date,
          startTime: event.startTime,
          endTime: event.endTime,
          duration: calculateDuration(event.startTime, event.endTime),
          effort: 0, 
          details: {
              specialties: event.technicalDetails?.specialties || [],
              snowCondition: event.technicalDetails?.snowCondition,
              weatherCondition: event.technicalDetails?.weatherCondition,
              freeSkiing: event.technicalDetails?.freeSkiing,
              gatedSkiing: event.technicalDetails?.gatedSkiing,
          }
      };
      
      setSessions(prev => {
          const clean = prev.filter(s => s.eventId !== event.id);
          return [...clean, newSession];
      });
  };

  // --- COACH EVENT HANDLERS ---
  const handleCoachEventSelect = (eventId: string) => {
      setSelectedCoachEventId(eventId);
      setNewCoachEventDate(null);
      setView('coach-event-details');
  };

  const handleCoachEventCreate = (date: string) => {
      setSelectedCoachEventId(null);
      setNewCoachEventDate(date);
      setView('coach-event-details');
  };

  const handleCoachEventSave = (updatedEvent: CalendarEvent) => {
      setCoachEvents(prev => {
          const exists = prev.find(e => e.id === updatedEvent.id);
          if (exists) return prev.map(e => e.id === updatedEvent.id ? updatedEvent : e);
          return [...prev, updatedEvent];
      });
      // Sync to athlete view immediately
      handleCoachSync(updatedEvent);
      
      if (currentView === 'coach-event-details') {
          setView('home'); 
      }
  };

  const handleCreateTeam = (newTeam: Team) => {
    setTeams(prev => [newTeam, ...prev]);
    setView('teams');
  };

  const handleTeamClick = (teamId: string) => {
    const team = teams.find(t => t.id === teamId);
    if (team) {
      setSelectedTeam(team);
      setView('team-details');
    }
  };

  const handleJoinTeam = (code: string): boolean => {
      const teamToJoin = ALL_AVAILABLE_TEAMS.find(t => t.inviteCode.toUpperCase() === code.toUpperCase());
      if (teamToJoin && !teams.some(t => t.id === teamToJoin.id)) {
          setTeams(prev => [teamToJoin, ...prev]);
          setSelectedTeam(teamToJoin);
          return true;
      }
      return false;
  };
  
  // Navigation Handler for Body Metrics ADD/CHART (from Home)
  const handleBodyMetricsAdd = (metric: 'weight' | 'height') => {
      setBodyMetricsTab(metric);
      setView('body-metrics');
  };

  // Navigation Handler for Body Metrics HISTORY (from Analytics)
  const handleBodyMetricsHistory = (metric: 'weight' | 'height') => {
      setBodyMetricsTab(metric);
      setView('all-body-metrics');
  };

  // Navigation Handler for Exercise Details from Analytics
  const handleExerciseClick = (exerciseId: string) => {
      setSelectedExerciseId(exerciseId);
      setView('exercise-details');
  };
  
  // Navigation Handler for Jump Details
  const handleJumpClick = (jumpType: JumpType) => {
    setSelectedJumpType(jumpType);
    setView('jump-details');
  };

  if (userProfile.role === 'coach' && localStorage.getItem('isLoggedIn') === 'true') {
    // If creating/editing event, show full screen details
    if (currentView === 'coach-event-details') {
        // ... (Event details logic remains same) ...
        // Prepare Event Data (Edit vs Create)
        let eventToEdit: CalendarEvent;
        
        if (selectedCoachEventId) {
            const found = coachEvents.find(e => e.id === selectedCoachEventId);
            if (!found) return <div onClick={() => setView('home')}>Event not found</div>;
            eventToEdit = found;
        } else {
            eventToEdit = {
                id: '', 
                teamId: teams[0]?.id || '',
                type: 'training',
                title: '',
                date: newCoachEventDate || new Date().toISOString().split('T')[0],
                startTime: '10:00',
                endTime: '12:00',
                technicalDetails: {
                    snowCondition: '',
                    weatherCondition: '',
                    specialties: [],
                    freeSkiing: { laps: '', changes: '' },
                    gatedSkiing: { laps: '', changes: '' }
                },
                attendees: MOCK_ATHLETES.map(a => ({ ...a, isPresent: true }))
            };
        }

        return (
            <CoachEventDetails 
                event={eventToEdit} 
                teams={teams}
                onSave={handleCoachEventSave}
                onBack={() => setView('home')}
            />
        );
    }

    // Default Coach View (Dashboard handles tabs: Home/Calendar, Reports, Workouts, Profile)
    return (
        <CoachDashboard 
            setView={setView} 
            userProfile={userProfile} 
            teams={teams} 
            events={coachEvents} 
            onLogout={handleLogout}
            onEventSelect={handleCoachEventSelect} 
            onCreateEvent={handleCoachEventCreate}
            onSyncSessions={handleCoachEventSave}
            onSaveProfile={handleSaveProfile}
        />
    );
  }

  const renderView = () => {
    switch (currentView) {
      case 'auth':
        return <Auth onRegister={handleRegister} onLogin={handleLogin} />;
      case 'home':
        return <Home 
            setView={setView} 
            userProfile={userProfile} 
            sessions={sessions} 
            bodyLogs={bodyLogs}
            onSessionClick={handleSessionEdit} 
            onBodyMetricsClick={handleBodyMetricsAdd}
        />;
      case 'analytics':
        return <Analytics 
            setView={setView} 
            unitSystem={userProfile.unitSystem} 
            language={userProfile.language} 
            sessions={sessions} 
            bodyLogs={bodyLogs}
            jumpLogs={jumpLogs}
            onSessionClick={handleSessionEdit} 
            onUpdateBodyLog={handleUpdateBodyLog}
            onDeleteBodyLog={handleDeleteBodyLog}
            onExerciseClick={handleExerciseClick}
            onJumpClick={handleJumpClick}
            onBodyMetricsClick={handleBodyMetricsHistory}
        />;
      case 'all-sessions':
        return <AllSessions setView={setView} sessions={sessions} onSessionClick={handleSessionEdit} />;
      case 'all-body-metrics':
        return <AllBodyMetrics 
            setView={setView} 
            metricType={bodyMetricsTab}
            bodyLogs={bodyLogs}
            unitSystem={userProfile.unitSystem}
            language={userProfile.language}
            onDeleteLog={handleDeleteBodyLog}
            onUpdateLog={handleUpdateBodyLog}
        />;
      case 'teams':
        return <Teams setView={setView} language={userProfile.language} teams={teams} onTeamClick={handleTeamClick} onJoinByCode={handleJoinTeam} />;
      case 'create-team':
        return <CreateTeam setView={setView} onCreateTeam={handleCreateTeam} />;
      case 'profile':
        return <Profile setView={setView} userProfile={userProfile} onSave={handleSaveProfile} onLogout={handleLogout} />;
      case 'add-training':
        return <AddTraining setView={setView} selectedSportId={selectedSportId} onSaveSession={handleSaveSession} initialSession={editingSession} userProfile={userProfile} />;
      case 'activity-select':
        return <ActivitySelect setView={setView} onSelectSport={handleSportSelect} />;
      case 'team-details':
        return <TeamDetails setView={setView} team={selectedTeam} />;
      case 'exercise-details':
        return <ExerciseDetails 
            setView={setView} 
            unitSystem={userProfile.unitSystem} 
            exerciseId={selectedExerciseId}
            prLogs={prLogs}
            onAddPR={handleAddPR}
            onDeletePR={handleDeletePR}
        />;
      case 'jump-details':
        return <JumpDetails 
            setView={setView}
            unitSystem={userProfile.unitSystem}
            jumpType={selectedJumpType}
            jumpLogs={jumpLogs}
            onAddJump={handleAddJump}
            onDeleteJump={handleDeleteJump}
        />;
      case 'body-metrics':
        return <BodyMetrics 
            setView={setView} 
            userProfile={userProfile} 
            onSaveLog={handleSaveBodyLog}
            bodyLogs={bodyLogs}
            initialMetric={bodyMetricsTab}
        />;
      default:
        return <Home setView={setView} userProfile={userProfile} sessions={sessions} />;
    }
  };

  return (
    <div className="bg-background text-white min-h-screen max-w-md mx-auto relative shadow-2xl overflow-hidden font-sans">
      {renderView()}
      {localStorage.getItem('isLoggedIn') === 'true' && userProfile.role === 'athlete' && <BottomNav currentView={currentView} setView={setView} language={userProfile.language} />}
    </div>
  );
}

export default App;
