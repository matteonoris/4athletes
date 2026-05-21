
export type ViewState = 
  | 'auth'
  | 'home' 
  | 'analytics' 
  | 'teams' 
  | 'create-team'
  | 'profile' 
  | 'add-training' 
  | 'add-training-skiing'
  | 'activity-select' 
  | 'team-details' 
  | 'exercise-details' 
  | 'jump-details'
  | 'body-metrics'
  | 'all-body-metrics'
  | 'all-sessions'
  | 'coach-event-details'; // New View

export type UnitSystem = 'metric' | 'imperial';
export type Language = 'en' | 'it';
export type UserRole = 'athlete' | 'coach';

export interface ConnectedDevice {
  id: string;
  name: string; // e.g. "Polar H10", "Garmin Connect"
  type: 'ble' | 'api'; // BLE direct or Cloud API
  provider: 'polar' | 'garmin' | 'whoop' | 'apple' | 'amazfit' | 'generic';
  status: 'connected' | 'disconnected' | 'syncing';
  batteryLevel?: number;
  lastSync?: string;
}

export interface UserProfile {
  firstName: string;
  lastName: string;
  email: string;
  birthDate: string;
  role: UserRole;
  weight: number; 
  height: number; 
  maxHr: number;
  unitSystem: UnitSystem;
  language: Language;
  avatarUrl: string;
  notificationsEnabled: boolean;
  connectedDevices: ConnectedDevice[]; // New field
  oneRepMax?: Record<string, number>;
}

export interface CalendarEvent {
  id: string;
  teamId: string;
  type: 'training' | 'match';
  title: string;
  date: string; // YYYY-MM-DD
  startTime: string;
  endTime: string;
  location?: string;
  notes?: string;
  sportCategory?: 'ski' | 'dryland';
  drylandSpecialty?: string;
  // New specific fields
  technicalDetails?: {
    snowCondition: string;
    weatherCondition: string;
    specialties: string[];
    freeSkiing: { changes: string; laps: string };
    gatedSkiing: { changes: string; laps: string };
  };
  attendees?: {
    id: string;
    name: string;
    isPresent: boolean;
    // Overrides for specific athlete
    lapsOverride?: string; 
  }[];
}

export interface BodyMetricLog {
  id: string;
  date: string;
  type: 'weight' | 'height';
  value: number; // Always stored in metric (kg or cm)
}

export interface PRLog {
  id: string;
  exerciseId: string;
  date: string;
  weight: number; // Stored in kg
  note?: string;
}

export type JumpType = 'squat_jump' | 'cm_jump' | 'drop_jump' | '45s_jump' | 'single_leg_left' | 'single_leg_right';

export interface JumpLog {
  id: string;
  date: string;
  type: JumpType;
  value: number; // Stored in cm
}

export interface Team {
  id: string;
  name: string;
  members: number;
  category: string;
  image: string;
  inviteCode: string;
  description?: string;
  isPrivate?: boolean;
}

export interface WeightliftingSet {
  id: string;
  reps: string;
  weight: string;
  rpe?: number;
  completed: boolean;
}

export interface WeightliftingExercise {
  id: string; 
  exerciseId: string; 
  name: string;
  sets: WeightliftingSet[];
}

export interface StretchingSet {
  id: string;
  duration: string; // seconds
  completed: boolean;
}

export interface StretchingExercise {
  id: string;
  exerciseId: string;
  name: string;
  sets: StretchingSet[];
}

export interface AthleticSet {
  id: string;
  distance?: string; // meters
  time?: string; // seconds
  reps?: string; // count
  completed: boolean;
}

export interface AthleticExercise {
  id: string;
  exerciseId: string;
  name: string;
  sets: AthleticSet[];
}

export interface TrainingSession {
  id: string;
  sportId: string;
  date: string;
  startTime: string;
  endTime: string;
  duration: string;
  effort: number;
  eventId?: string; // Link back to Coach Event
  details?: {
    specialties?: string[];
    freeSkiing?: { changes: string, laps: string };
    gatedSkiing?: { changes: string, laps: string };
    snowCondition?: string;
    weatherCondition?: string;
    painZones?: string[];
    timeTrials?: { id: string, time: string, material: string }[];
    weightlifting?: {
      exercises: WeightliftingExercise[];
    };
    stretching?: {
      exercises: StretchingExercise[];
    };
    athletic?: {
      exercises: AthleticExercise[];
    };
    running?: {
      distance: string;
      avgPace: string;
      avgHr: string;
      maxHr: string;
      elevation: string;
      cadence: string;
      shoes: string;
      surface: string;
    };
    football?: {
        type: 'match' | 'training';
        goals?: string;
        assists?: string;
        result?: 'win' | 'loss' | 'draw';
        opponent?: string;
        position?: string;
    };
    tennis?: {
        type: 'match' | 'practice';
        result?: 'win' | 'loss';
        score?: string; // e.g. 6-4 6-2
        surface?: string;
        opponent?: string;
        aces?: string;
        doubleFaults?: string;
    };
    cycling?: {
        type: 'indoor' | 'road' | 'mtb' | 'gravel';
        distance?: string;
        avgSpeed?: string;
        avgPower?: string; // Watts
        avgCadence?: string;
        avgHr?: string;
        elevation?: string;
    };
  };
}
