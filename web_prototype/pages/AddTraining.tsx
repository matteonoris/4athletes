
import React, { useState } from 'react';
import { 
  X, ChevronRight, Calendar, Clock, Activity, Plus, Trash2, 
  Snowflake, Cloud, Zap, Timer, Package, AlertTriangle, ChevronDown,
  Search, Dumbbell, MoreVertical, Footprints, Mountain, Heart, Gauge, Map,
  Goal, Trophy, Users, Bike, Wind, Move, ChevronsRight
} from 'lucide-react';
import { ViewState, TrainingSession, WeightliftingExercise, WeightliftingSet, UserProfile, StretchingExercise, StretchingSet, AthleticExercise, AthleticSet } from '../types';
import { sportsData } from '../data/sports';
import { exerciseDatabase } from '../data/exercises';

interface Props {
  setView: (view: ViewState) => void;
  selectedSportId?: string;
  onSaveSession: (session: TrainingSession) => void;
  initialSession?: TrainingSession; // Optional prop for editing mode
  userProfile?: UserProfile;
}

interface TimeTrial {
  id: string;
  time: string;
  material: string;
}

const AddTraining: React.FC<Props> = ({ setView, selectedSportId, onSaveSession, initialSession, userProfile }) => {
  // --- Initialize state based on initialSession if it exists (Edit Mode) ---
  const [effort, setEffort] = useState(initialSession?.effort ?? 5);
  const [date, setDate] = useState(() => initialSession?.date ?? new Date().toISOString().split('T')[0]);
  const [startTime, setStartTime] = useState(initialSession?.startTime ?? '09:00');
  const [endTime, setEndTime] = useState(initialSession?.endTime ?? '11:30');

  // --- ALPINE SKIING SPECIFIC STATE ---
  const [specialties, setSpecialties] = useState<string[]>(initialSession?.details?.specialties ?? []);
  const [freeSkiing, setFreeSkiing] = useState({ 
    changes: initialSession?.details?.freeSkiing?.changes ?? '', 
    laps: initialSession?.details?.freeSkiing?.laps ?? '' 
  });
  const [gatedSkiing, setGatedSkiing] = useState({ 
    changes: initialSession?.details?.gatedSkiing?.changes ?? '', 
    laps: initialSession?.details?.gatedSkiing?.laps ?? '' 
  });
  const [snowCondition, setSnowCondition] = useState(initialSession?.details?.snowCondition ?? '');
  const [weatherCondition, setWeatherCondition] = useState(initialSession?.details?.weatherCondition ?? '');
  
  // --- RUNNING SPECIFIC STATE ---
  const [runDistance, setRunDistance] = useState(initialSession?.details?.running?.distance ?? '');
  const [runPace, setRunPace] = useState(initialSession?.details?.running?.avgPace ?? '');
  const [runAvgHr, setRunAvgHr] = useState(initialSession?.details?.running?.avgHr ?? '');
  const [runMaxHr, setRunMaxHr] = useState(initialSession?.details?.running?.maxHr ?? '');
  const [runElevation, setRunElevation] = useState(initialSession?.details?.running?.elevation ?? '');
  const [runCadence, setRunCadence] = useState(initialSession?.details?.running?.cadence ?? '');
  const [runShoes, setRunShoes] = useState(initialSession?.details?.running?.shoes ?? '');
  const [runSurface, setRunSurface] = useState(initialSession?.details?.running?.surface ?? '');

  // --- FOOTBALL (SOCCER) SPECIFIC STATE ---
  const [fbType, setFbType] = useState<'match' | 'training'>(initialSession?.details?.football?.type ?? 'training');
  const [fbGoals, setFbGoals] = useState(initialSession?.details?.football?.goals ?? '');
  const [fbAssists, setFbAssists] = useState(initialSession?.details?.football?.assists ?? '');
  const [fbResult, setFbResult] = useState(initialSession?.details?.football?.result ?? undefined);
  const [fbOpponent, setFbOpponent] = useState(initialSession?.details?.football?.opponent ?? '');
  const [fbPosition, setFbPosition] = useState(initialSession?.details?.football?.position ?? '');

  // --- TENNIS / PADEL SPECIFIC STATE ---
  const [tennisType, setTennisType] = useState<'match' | 'practice'>(initialSession?.details?.tennis?.type ?? 'practice');
  const [tennisResult, setTennisResult] = useState(initialSession?.details?.tennis?.result ?? undefined);
  const [tennisScore, setTennisScore] = useState(initialSession?.details?.tennis?.score ?? '');
  const [tennisSurface, setTennisSurface] = useState(initialSession?.details?.tennis?.surface ?? '');
  const [tennisOpponent, setTennisOpponent] = useState(initialSession?.details?.tennis?.opponent ?? '');
  const [tennisAces, setTennisAces] = useState(initialSession?.details?.tennis?.aces ?? '');

  // --- CYCLING SPECIFIC STATE ---
  const [cycType, setCycType] = useState(initialSession?.details?.cycling?.type ?? 'road');
  const [cycDistance, setCycDistance] = useState(initialSession?.details?.cycling?.distance ?? '');
  const [cycAvgSpeed, setCycAvgSpeed] = useState(initialSession?.details?.cycling?.avgSpeed ?? '');
  const [cycPower, setCycPower] = useState(initialSession?.details?.cycling?.avgPower ?? '');
  const [cycCadence, setCycCadence] = useState(initialSession?.details?.cycling?.avgCadence ?? '');
  const [cycElevation, setCycElevation] = useState(initialSession?.details?.cycling?.elevation ?? '');
  const [cycAvgHr, setCycAvgHr] = useState(initialSession?.details?.cycling?.avgHr ?? '');

  // Pain Monitoring State Initialization
  const [painZones, setPainZones] = useState<string[]>(() => {
    if (!initialSession?.details?.painZones) return [];
    return initialSession.details.painZones.map(z => z.startsWith('Other:') ? 'Other (Altro)' : z);
  });
  
  const [otherPain, setOtherPain] = useState(() => {
    if (!initialSession?.details?.painZones) return '';
    const other = initialSession.details.painZones.find(z => z.startsWith('Other:'));
    return other ? other.replace('Other: ', '') : '';
  });
  
  // Time Trials State
  const [timeTrials, setTimeTrials] = useState<TimeTrial[]>(
    initialSession?.details?.timeTrials ?? []
  );

  // --- WEIGHTLIFTING SPECIFIC STATE ---
  const [wlExercises, setWlExercises] = useState<WeightliftingExercise[]>(
    initialSession?.details?.weightlifting?.exercises ?? []
  );

  // --- STRETCHING SPECIFIC STATE ---
  const [stretchingExercises, setStretchingExercises] = useState<StretchingExercise[]>(
    initialSession?.details?.stretching?.exercises ?? []
  );

  // --- ATHLETIC PREP (WARMUP/SPRINT) STATE ---
  const [athleticExercises, setAthleticExercises] = useState<AthleticExercise[]>(
    initialSession?.details?.athletic?.exercises ?? []
  );

  const [showExercisePicker, setShowExercisePicker] = useState(false);
  const [exerciseSearch, setExerciseSearch] = useState('');

  const sportIdToUse = initialSession?.sportId ?? selectedSportId ?? 'weightlifting';
  const sport = sportsData.find(s => s.id === sportIdToUse) || sportsData.find(s => s.id === 'weightlifting')!;
  const SportIcon = sport.icon;
  
  // Feature flags based on sport
  const isSkiing = sport.id === 'alpine_skiing';
  const isWeightlifting = sport.id === 'weightlifting' || sport.id === 'powerlifting' || sport.id === 'crossfit' || sport.id === 'bodybuilding';
  const isRunning = sport.id.includes('running') || sport.id === 'track_field';
  const isFootball = sport.id === 'soccer' || sport.id === 'am_football' || sport.id === 'rugby';
  const isTennis = sport.id === 'tennis' || sport.id === 'padel' || sport.id === 'pickleball' || sport.id === 'squash';
  const isCycling = sport.id.includes('cycling') || sport.id === 'spinning';
  const isStretching = sport.id === 'stretching' || sport.id === 'yoga' || sport.id === 'pilates';
  const isAthletic = sport.id === 'athletic_prep' || sport.id === 'other'; // Handle generic Athletic Prep
  const isSynced = !!initialSession?.eventId;

  // --- HANDLERS FOR WEIGHTLIFTING / STRETCHING / ATHLETIC ---
  const handleAddExercise = (exerciseDefId: string, name: string) => {
    if (isStretching) {
        setStretchingExercises([...stretchingExercises, {
            id: Date.now().toString(),
            exerciseId: exerciseDefId,
            name: name,
            sets: [{ id: Date.now().toString() + '-1', duration: '', completed: false }]
        }]);
    } else if (isAthletic) {
        setAthleticExercises([...athleticExercises, {
            id: Date.now().toString(),
            exerciseId: exerciseDefId,
            name: name,
            sets: [{ id: Date.now().toString() + '-1', completed: false }]
        }]);
    } else {
        setWlExercises([...wlExercises, {
            id: Date.now().toString(),
            exerciseId: exerciseDefId,
            name: name,
            sets: [{ id: Date.now().toString() + '-1', reps: '', weight: '', completed: false }]
        }]);
    }
    setShowExercisePicker(false);
    setExerciseSearch('');
  };

  const handleAddSet = (exerciseInstanceId: string) => {
    if (isStretching) {
        setStretchingExercises(prev => prev.map(ex => ex.id === exerciseInstanceId ? {
            ...ex,
            sets: [...ex.sets, { id: Date.now().toString(), duration: ex.sets[ex.sets.length-1]?.duration || '', completed: false }]
        } : ex));
    } else if (isAthletic) {
        setAthleticExercises(prev => prev.map(ex => ex.id === exerciseInstanceId ? {
            ...ex,
            sets: [...ex.sets, { 
                id: Date.now().toString(), 
                distance: ex.sets[ex.sets.length-1]?.distance || '', 
                reps: ex.sets[ex.sets.length-1]?.reps || '',
                time: ex.sets[ex.sets.length-1]?.time || '',
                completed: false 
            }]
        } : ex));
    } else {
        setWlExercises(prev => prev.map(ex => ex.id === exerciseInstanceId ? {
            ...ex,
            sets: [...ex.sets, { 
                id: Date.now().toString(), 
                reps: ex.sets[ex.sets.length-1]?.reps || '', 
                weight: ex.sets[ex.sets.length-1]?.weight || '', 
                completed: false 
            }]
        } : ex));
    }
  };

  const handleUpdateSet = (exerciseInstanceId: string, setId: string, field: string, value: any) => {
    if (isStretching) {
        setStretchingExercises(prev => prev.map(ex => ex.id === exerciseInstanceId ? {
            ...ex, sets: ex.sets.map(s => s.id === setId ? { ...s, [field]: value } : s)
        } : ex));
    } else if (isAthletic) {
        setAthleticExercises(prev => prev.map(ex => ex.id === exerciseInstanceId ? {
            ...ex, sets: ex.sets.map(s => s.id === setId ? { ...s, [field]: value } : s)
        } : ex));
    } else {
        setWlExercises(prev => prev.map(ex => ex.id === exerciseInstanceId ? {
            ...ex, sets: ex.sets.map(s => s.id === setId ? { ...s, [field]: value } : s)
        } : ex));
    }
  };

  const handleRemoveSet = (exerciseInstanceId: string, setId: string) => {
    if (isStretching) {
        setStretchingExercises(prev => prev.map(ex => ex.id === exerciseInstanceId ? {
            ...ex, sets: ex.sets.filter(s => s.id !== setId)
        } : ex).filter(ex => ex.sets.length > 0));
    } else if (isAthletic) {
        setAthleticExercises(prev => prev.map(ex => ex.id === exerciseInstanceId ? {
            ...ex, sets: ex.sets.filter(s => s.id !== setId)
        } : ex).filter(ex => ex.sets.length > 0));
    } else {
        setWlExercises(prev => prev.map(ex => ex.id === exerciseInstanceId ? {
            ...ex, sets: ex.sets.filter(s => s.id !== setId)
        } : ex).filter(ex => ex.sets.length > 0));
    }
  };

  const handleRemoveExercise = (exerciseInstanceId: string) => {
    if (isStretching) setStretchingExercises(prev => prev.filter(ex => ex.id !== exerciseInstanceId));
    else if (isAthletic) setAthleticExercises(prev => prev.filter(ex => ex.id !== exerciseInstanceId));
    else setWlExercises(prev => prev.filter(ex => ex.id !== exerciseInstanceId));
  };

  const get1RMPercentage = (exerciseId: string, weight: string) => {
     if (!userProfile?.oneRepMax || !weight) return null;
     const max = userProfile.oneRepMax[exerciseId];
     const w = parseFloat(weight);
     if (!max || isNaN(w)) return null;
     return Math.round((w / max) * 100);
  };

  // --- GENERAL HANDLERS ---
  const toggleSpecialty = (s: string) => {
    setSpecialties(prev => prev.includes(s) ? prev.filter(item => item !== s) : [...prev, s]);
  };

  const togglePainZone = (zone: string) => {
    setPainZones(prev => prev.includes(zone) ? prev.filter(z => z !== zone) : [...prev, zone]);
  };

  const addTrial = () => {
    const newId = Date.now().toString();
    setTimeTrials([...timeTrials, { id: newId, time: '', material: '' }]);
  };

  const updateTrial = (id: string, field: keyof TimeTrial, value: string) => {
    setTimeTrials(prev => prev.map(t => t.id === id ? { ...t, [field]: value } : t));
  };

  const removeTrial = (id: string) => {
    setTimeTrials(timeTrials.filter(t => t.id !== id));
  };

  const calculateDuration = (start: string, end: string) => {
    const [startH, startM] = start.split(':').map(Number);
    const [endH, endM] = end.split(':').map(Number);
    let diffM = (endH * 60 + endM) - (startH * 60 + startM);
    if (diffM < 0) diffM += 24 * 60; // Handle overnight
    const h = Math.floor(diffM / 60);
    const m = diffM % 60;
    return `${h}h ${m}m`;
  };

  const handleSave = () => {
    const newSession: TrainingSession = {
        // Reuse ID if editing, otherwise create new
        id: initialSession?.id ?? Date.now().toString(),
        sportId: sport.id,
        date: date,
        startTime: startTime,
        endTime: endTime,
        duration: calculateDuration(startTime, endTime),
        effort: effort,
        details: {
            painZones: painZones.includes('Other (Altro)') && otherPain ? [...painZones.filter(z => z !== 'Other (Altro)'), `Other: ${otherPain}`] : painZones,
            // Skiing Data
            ...(isSkiing ? {
                specialties,
                freeSkiing,
                gatedSkiing,
                snowCondition,
                weatherCondition,
                timeTrials
            } : {}),
            // Weightlifting Data
            ...(isWeightlifting ? {
                weightlifting: {
                    exercises: wlExercises
                }
            } : {}),
            // Stretching Data
            ...(isStretching ? {
                stretching: {
                    exercises: stretchingExercises
                }
            } : {}),
            // Athletic Prep Data
            ...(isAthletic ? {
                athletic: {
                    exercises: athleticExercises
                }
            } : {}),
            // Running Data
            ...(isRunning ? {
                running: {
                    distance: runDistance,
                    avgPace: runPace,
                    avgHr: runAvgHr,
                    maxHr: runMaxHr,
                    elevation: runElevation,
                    cadence: runCadence,
                    shoes: runShoes,
                    surface: runSurface
                }
            } : {}),
            // Football Data
            ...(isFootball ? {
                football: {
                    type: fbType,
                    goals: fbGoals,
                    assists: fbAssists,
                    result: fbResult,
                    opponent: fbOpponent,
                    position: fbPosition
                }
            } : {}),
            // Tennis Data
            ...(isTennis ? {
                tennis: {
                    type: tennisType,
                    result: tennisResult,
                    score: tennisScore,
                    surface: tennisSurface,
                    opponent: tennisOpponent,
                    aces: tennisAces
                }
            } : {}),
            // Cycling Data
            ...(isCycling ? {
                cycling: {
                    type: cycType as any,
                    distance: cycDistance,
                    avgSpeed: cycAvgSpeed,
                    avgPower: cycPower,
                    avgCadence: cycCadence,
                    avgHr: cycAvgHr,
                    elevation: cycElevation
                }
            } : {})
        }
    };

    onSaveSession(newSession);
  };

  const getEffortColor = (val: number) => {
    if (val <= 3) return 'text-primary'; 
    if (val <= 7) return 'text-secondary';
    return 'text-orange-500'; 
  };

  const getEffortLabel = (val: number) => {
    if (val <= 2) return 'Molto Leggero';
    if (val <= 4) return 'Leggero';
    if (val <= 6) return 'Moderato';
    if (val <= 8) return 'Intenso';
    return 'Sforzo Massimo';
  };

  const fillPercent = ((effort - 1) / 9) * 100;
  const fillColor = effort <= 3 ? '#00E091' : effort <= 7 ? '#13A4EC' : '#F97316';

  const filteredDatabase = exerciseDatabase.filter(ex => {
     const matchesSearch = ex.name.toLowerCase().includes(exerciseSearch.toLowerCase());
     if (isStretching) return matchesSearch && ex.category === 'Stretching';
     if (isAthletic) return matchesSearch && (ex.category === 'Warm-up' || ex.category === 'Sprints' || ex.category === 'Plyometrics');
     // Default filter for generic weightlifting/fitness
     return matchesSearch && ex.category !== 'Stretching' && ex.category !== 'Warm-up' && ex.category !== 'Sprints' && ex.category !== 'Plyometrics';
  });

  return (
    <div className="fixed inset-0 z-50 bg-background flex flex-col animate-in slide-in-from-bottom duration-300">
      
      {/* Exercise Picker Modal */}
      {showExercisePicker && (
        <div className="fixed inset-0 z-[60] bg-background flex flex-col animate-in slide-in-from-bottom duration-200">
            <div className="p-4 border-b border-white/5 flex items-center gap-3">
                <button onClick={() => setShowExercisePicker(false)} className="p-2 -ml-2 rounded-full hover:bg-white/10">
                    <X className="w-6 h-6" />
                </button>
                <div className="flex-1 relative">
                    <Search className="absolute left-3 top-2.5 w-4 h-4 text-gray-500" />
                    <input 
                        autoFocus
                        type="text" 
                        placeholder={isStretching ? "Search stretch..." : isAthletic ? "Search drill/sprint..." : "Search exercise..."}
                        value={exerciseSearch}
                        onChange={(e) => setExerciseSearch(e.target.value)}
                        className="w-full bg-surface border-none rounded-xl py-2 pl-9 pr-4 text-sm text-white focus:ring-1 focus:ring-secondary"
                    />
                </div>
            </div>
            <div className="flex-1 overflow-y-auto p-4 space-y-2">
                {filteredDatabase.map(ex => (
                    <button 
                        key={ex.id}
                        onClick={() => handleAddExercise(ex.id, ex.name)}
                        className="w-full text-left p-4 bg-card border border-white/5 rounded-xl hover:border-secondary/50 active:scale-[0.99] transition flex justify-between items-center"
                    >
                        <span className="font-bold text-sm">{ex.name}</span>
                        <span className="text-xs text-gray-500 font-mono uppercase bg-white/5 px-2 py-1 rounded">{ex.category}</span>
                    </button>
                ))}
            </div>
        </div>
      )}

      <header className="flex items-center justify-between p-4 border-b border-white/5 bg-surface/80 backdrop-blur-lg sticky top-0 z-10">
        <button onClick={() => setView('home')} className="p-2 hover:bg-white/10 rounded-full transition-colors">
            <X className="text-gray-400 w-6 h-6" />
        </button>
        <h1 className="text-sm font-bold uppercase tracking-widest flex items-center gap-2">
            {initialSession ? 'Edit' : 'Log'} <span className="text-secondary">{sport.name}</span>
        </h1>
        <div className="w-10"></div>
      </header>

      <div className="flex-1 overflow-y-auto p-4 space-y-6 pb-32">
        
        {/* Activity Selector Card */}
        <div 
            onClick={() => setView('activity-select')} 
            className="w-full p-4 bg-card rounded-2xl border border-secondary/30 flex items-center justify-between active:scale-[0.98] transition cursor-pointer"
        >
            <div className="flex items-center gap-4">
                <div className="w-12 h-12 rounded-xl bg-secondary/10 flex items-center justify-center text-secondary">
                    <SportIcon className="w-6 h-6" />
                </div>
                <div>
                    <span className="font-bold tracking-wide uppercase text-[10px] text-gray-500 block">Tipo Attività</span>
                    <span className="text-lg font-bold block">{sport.name}</span>
                </div>
            </div>
            <ChevronRight className="text-gray-600 w-5 h-5" />
        </div>

        {/* Coach Specifications Card (if synced from a coach event) */}
        {isSynced && (
          <div className={`p-4 rounded-2xl border ${
            isSkiing 
              ? 'bg-gradient-to-r from-secondary/15 via-sky-500/5 to-card/50 border-secondary/30 shadow-lg shadow-secondary/5' 
              : 'bg-gradient-to-r from-orange-500/15 via-amber-500/5 to-card/50 border-orange-500/30 shadow-lg shadow-orange-500/5'
          } space-y-4 animate-in fade-in slide-in-from-top-4 duration-300`}>
              <div className="flex items-center justify-between pb-2 border-b border-white/5">
                  <div className="flex items-center gap-2.5">
                      <div className={`w-8 h-8 rounded-lg flex items-center justify-center ${isSkiing ? 'bg-secondary/20 text-secondary' : 'bg-orange-500/20 text-orange-500'}`}>
                          {isSkiing ? <Trophy className="w-4 h-4" /> : <Dumbbell className="w-4 h-4" />}
                      </div>
                      <div>
                          <span className="text-[10px] font-bold uppercase tracking-widest text-gray-400 block">Dettagli Allenatore</span>
                          <span className="text-xs font-semibold text-gray-300 block">Programmato dal Coach</span>
                      </div>
                  </div>
                  <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full uppercase tracking-wider ${
                      isSkiing ? 'bg-secondary/10 text-secondary border border-secondary/20' : 'bg-orange-500/10 text-orange-500 border border-orange-500/20'
                  }`}>
                      Sincronizzato
                  </span>
              </div>

              {isSkiing ? (
                  <div className="grid grid-cols-2 gap-4 text-sm">
                      {/* Specialties */}
                      {initialSession?.details?.specialties && initialSession.details.specialties.length > 0 && (
                          <div className="col-span-2 space-y-1">
                              <span className="text-[9px] text-gray-500 font-bold uppercase tracking-wider block">Specialità sciistiche</span>
                              <div className="flex gap-1.5 flex-wrap">
                                  {initialSession.details.specialties.map(spec => (
                                      <span key={spec} className="px-2.5 py-1 bg-secondary/15 text-secondary border border-secondary/20 rounded-lg text-xs font-bold font-mono">
                                          {spec}
                                      </span>
                                  ))}
                              </div>
                          </div>
                      )}

                      {/* Conditions */}
                      {(initialSession?.details?.weatherCondition || initialSession?.details?.snowCondition) && (
                          <div className="col-span-2 grid grid-cols-2 gap-3 bg-white/5 rounded-xl p-2.5 border border-white/5">
                              {initialSession.details.weatherCondition && (
                                  <div className="flex items-center gap-2">
                                      <Cloud className="w-4 h-4 text-sky-400 shrink-0" />
                                      <div>
                                          <span className="text-[8px] text-gray-500 uppercase block font-bold">Meteo</span>
                                          <span className="text-xs font-bold capitalize text-white">{initialSession.details.weatherCondition}</span>
                                      </div>
                                  </div>
                              )}
                              {initialSession.details.snowCondition && (
                                  <div className="flex items-center gap-2">
                                      <Snowflake className="w-4 h-4 text-cyan-400 shrink-0" />
                                      <div>
                                          <span className="text-[8px] text-gray-500 uppercase block font-bold">Neve</span>
                                          <span className="text-xs font-bold capitalize text-white">{initialSession.details.snowCondition}</span>
                                      </div>
                                  </div>
                              )}
                          </div>
                      )}

                      {/* Free Skiing Volume */}
                      {initialSession?.details?.freeSkiing && (initialSession.details.freeSkiing.laps || initialSession.details.freeSkiing.changes) && (
                          <div className="space-y-1 bg-white/5 border border-white/5 rounded-xl p-3">
                              <div className="flex items-center gap-1.5 text-primary">
                                  <Activity className="w-3.5 h-3.5" />
                                  <span className="text-[10px] font-bold uppercase tracking-wide">Campo Libero</span>
                              </div>
                              <div className="mt-1 text-xs space-y-0.5">
                                  {initialSession.details.freeSkiing.laps && (
                                      <p className="text-gray-400 font-medium">Giri: <span className="font-bold text-white">{initialSession.details.freeSkiing.laps}</span></p>
                                  )}
                                  {initialSession.details.freeSkiing.changes && (
                                      <p className="text-gray-400 font-medium">Cambi: <span className="font-bold text-white">{initialSession.details.freeSkiing.changes}</span></p>
                                  )}
                              </div>
                          </div>
                      )}

                      {/* Gated Skiing Volume */}
                      {initialSession?.details?.gatedSkiing && (initialSession.details.gatedSkiing.laps || initialSession.details.gatedSkiing.changes) && (
                          <div className="space-y-1 bg-white/5 border border-white/5 rounded-xl p-3">
                              <div className="flex items-center gap-1.5 text-secondary">
                                  <Zap className="w-3.5 h-3.5" />
                                  <span className="text-[10px] font-bold uppercase tracking-wide">Pali (Volume)</span>
                              </div>
                              <div className="mt-1 text-xs space-y-0.5">
                                  {initialSession.details.gatedSkiing.laps && (
                                      <p className="text-gray-400 font-medium">Giri: <span className="font-bold text-white">{initialSession.details.gatedSkiing.laps}</span></p>
                                  )}
                                  {initialSession.details.gatedSkiing.changes && (
                                      <p className="text-gray-400 font-medium">Porte: <span className="font-bold text-white">{initialSession.details.gatedSkiing.changes}</span></p>
                                  )}
                              </div>
                          </div>
                      )}
                  </div>
              ) : (
                  /* Dryland/Athletic specifications */
                  <div className="space-y-3">
                      {initialSession?.details?.specialties && initialSession.details.specialties.length > 0 && (
                          <div className="space-y-1">
                              <span className="text-[9px] text-gray-500 font-bold uppercase tracking-wider block">Specialità Atletica</span>
                              <div className="flex gap-1.5 flex-wrap">
                                  {initialSession.details.specialties.map(spec => (
                                      <span key={spec} className="px-3 py-1.5 bg-orange-500/10 text-orange-500 border border-orange-500/20 rounded-xl text-sm font-bold">
                                          {spec}
                                      </span>
                                  ))}
                              </div>
                          </div>
                      )}
                      <p className="text-xs text-gray-400 leading-relaxed font-medium">
                          Inserisci le tue metriche di allenamento (RPE, report dolore, esercizi svolti) per completare il log della sessione programmata dall'allenatore.
                      </p>
                  </div>
              )}
          </div>
        )}

        {/* DateTime Section */}
        <section className="bg-card rounded-2xl border border-white/5 overflow-hidden">
            <div className="p-4 border-b border-white/5 flex items-center justify-between">
                <div className="flex items-center gap-3">
                    <Calendar className="w-5 h-5 text-gray-500" />
                    <span className="font-semibold text-sm">Data</span>
                </div>
                <input 
                    type="date" 
                    value={date}
                    onChange={(e) => setDate(e.target.value)}
                    className="bg-transparent text-right font-bold text-white border-none focus:ring-0 cursor-pointer text-sm"
                />
            </div>
            <div className="flex divide-x divide-white/5">
                <div className="flex-1 p-4 flex flex-col gap-1">
                    <span className="text-[10px] font-bold text-gray-500 uppercase">Inizio</span>
                    <input 
                        type="time" 
                        value={startTime}
                        onChange={(e) => setStartTime(e.target.value)}
                        className="bg-transparent font-bold text-lg text-white border-none focus:ring-0 p-0 cursor-pointer"
                    />
                </div>
                <div className="flex-1 p-4 flex flex-col gap-1">
                    <span className="text-[10px] font-bold text-gray-500 uppercase">Fine</span>
                    <input 
                        type="time" 
                        value={endTime}
                        onChange={(e) => setEndTime(e.target.value)}
                        className="bg-transparent font-bold text-lg text-white border-none focus:ring-0 p-0 cursor-pointer"
                    />
                </div>
            </div>
        </section>

        {/* --- ATHLETIC PREP (OTHER) SPECIFIC SECTIONS --- */}
        {isAthletic && (
            <div className="space-y-4 animate-in fade-in slide-in-from-top-4 duration-500">
                <div className="flex items-center justify-between px-1">
                    <h3 className="text-xs font-bold uppercase tracking-widest text-gray-500">Prep. Atletica & Riscaldamento</h3>
                    <button 
                        onClick={() => setShowExercisePicker(true)}
                        className="text-secondary text-xs font-bold uppercase flex items-center gap-1 hover:underline"
                    >
                        <Plus className="w-3 h-3" /> Aggiungi Esercizio
                    </button>
                </div>

                {athleticExercises.map((exercise) => (
                    <div key={exercise.id} className="bg-card rounded-2xl border border-white/5 overflow-hidden">
                        <div className="p-4 bg-white/5 flex justify-between items-center">
                            <h3 className="font-bold text-base">{exercise.name}</h3>
                            <button onClick={() => handleRemoveExercise(exercise.id)} className="text-gray-500 hover:text-red-500 transition">
                                <Trash2 className="w-4 h-4" />
                            </button>
                        </div>
                        <div className="p-2">
                             <div className="grid grid-cols-10 gap-2 mb-2 px-2 text-[10px] font-bold uppercase text-gray-500 text-center">
                                <div className="col-span-1">Set</div>
                                <div className="col-span-3">Dist (m)</div>
                                <div className="col-span-2">Reps</div>
                                <div className="col-span-3">Tempo (s)</div>
                                <div className="col-span-1"></div>
                             </div>
                             
                             <div className="space-y-2">
                                {exercise.sets.map((set, setIndex) => (
                                    <div key={set.id} className="grid grid-cols-10 gap-2 items-center">
                                        <div className="col-span-1 flex justify-center">
                                            <div className="w-6 h-6 rounded-full bg-surface border border-white/10 flex items-center justify-center text-xs font-bold text-gray-400">
                                                {setIndex + 1}
                                            </div>
                                        </div>
                                        <div className="col-span-3">
                                            <input 
                                                type="number" 
                                                placeholder="m"
                                                value={set.distance}
                                                onChange={(e) => handleUpdateSet(exercise.id, set.id, 'distance', e.target.value)}
                                                className="w-full bg-surface border-none rounded-lg p-2 text-center text-sm font-bold focus:ring-1 focus:ring-secondary placeholder:font-normal placeholder:text-gray-600"
                                            />
                                        </div>
                                        <div className="col-span-2">
                                            <input 
                                                type="number" 
                                                placeholder="n°"
                                                value={set.reps}
                                                onChange={(e) => handleUpdateSet(exercise.id, set.id, 'reps', e.target.value)}
                                                className="w-full bg-surface border-none rounded-lg p-2 text-center text-sm font-bold focus:ring-1 focus:ring-secondary placeholder:font-normal placeholder:text-gray-600"
                                            />
                                        </div>
                                        <div className="col-span-3">
                                            <input 
                                                type="number" 
                                                placeholder="sec"
                                                value={set.time}
                                                onChange={(e) => handleUpdateSet(exercise.id, set.id, 'time', e.target.value)}
                                                className="w-full bg-surface border-none rounded-lg p-2 text-center text-sm font-bold focus:ring-1 focus:ring-secondary placeholder:font-normal placeholder:text-gray-600"
                                            />
                                        </div>
                                        <div className="col-span-1 flex justify-center">
                                             <button onClick={() => handleRemoveSet(exercise.id, set.id)} className="text-gray-600 hover:text-red-500">
                                                <X className="w-4 h-4" />
                                             </button>
                                        </div>
                                    </div>
                                ))}
                             </div>

                             <button 
                                onClick={() => handleAddSet(exercise.id)}
                                className="w-full mt-3 py-2 flex items-center justify-center gap-1 text-xs font-bold text-gray-500 hover:text-white hover:bg-white/5 rounded-lg transition"
                             >
                                <Plus className="w-3 h-3" /> Aggiungi Set
                             </button>
                        </div>
                    </div>
                ))}
                
                {athleticExercises.length === 0 && (
                    <button 
                        onClick={() => setShowExercisePicker(true)}
                        className="w-full py-8 border-2 border-dashed border-white/10 rounded-2xl flex flex-col items-center justify-center gap-2 text-gray-500 hover:text-secondary hover:border-secondary/30 transition-all active:scale-[0.98]"
                    >
                        <ChevronsRight className="w-8 h-8 opacity-50" />
                        <span className="text-sm font-bold uppercase tracking-wider">Inizia Esercizi</span>
                        <span className="text-[10px] text-gray-600">Riscaldamento, Scatti, Balzi...</span>
                    </button>
                )}
            </div>
        )}

        {/* --- STRETCHING SPECIFIC SECTIONS --- */}
        {isStretching && (
            <div className="space-y-4 animate-in fade-in slide-in-from-top-4 duration-500">
                <div className="flex items-center justify-between px-1">
                    <h3 className="text-xs font-bold uppercase tracking-widest text-gray-500">Sessione Allungamento</h3>
                    <button 
                        onClick={() => setShowExercisePicker(true)}
                        className="text-secondary text-xs font-bold uppercase flex items-center gap-1 hover:underline"
                    >
                        <Plus className="w-3 h-3" /> Aggiungi Esercizio
                    </button>
                </div>

                {stretchingExercises.map((exercise) => (
                    <div key={exercise.id} className="bg-card rounded-2xl border border-white/5 overflow-hidden">
                        <div className="p-4 bg-white/5 flex justify-between items-center">
                            <h3 className="font-bold text-base">{exercise.name}</h3>
                            <button onClick={() => handleRemoveExercise(exercise.id)} className="text-gray-500 hover:text-red-500 transition">
                                <Trash2 className="w-4 h-4" />
                            </button>
                        </div>
                        <div className="p-2">
                             <div className="grid grid-cols-6 gap-2 mb-2 px-2 text-[10px] font-bold uppercase text-gray-500 text-center">
                                <div className="col-span-1">Set</div>
                                <div className="col-span-4">Durata (secondi)</div>
                                <div className="col-span-1"></div>
                             </div>
                             
                             <div className="space-y-2">
                                {exercise.sets.map((set, setIndex) => (
                                    <div key={set.id} className="grid grid-cols-6 gap-2 items-center">
                                        <div className="col-span-1 flex justify-center">
                                            <div className="w-6 h-6 rounded-full bg-surface border border-white/10 flex items-center justify-center text-xs font-bold text-gray-400">
                                                {setIndex + 1}
                                            </div>
                                        </div>
                                        <div className="col-span-4">
                                            <input 
                                                type="number" 
                                                placeholder="sec"
                                                value={set.duration}
                                                onChange={(e) => handleUpdateSet(exercise.id, set.id, 'duration', e.target.value)}
                                                className="w-full bg-surface border-none rounded-lg p-2 text-center text-sm font-bold focus:ring-1 focus:ring-secondary"
                                            />
                                        </div>
                                        <div className="col-span-1 flex justify-center">
                                             <button onClick={() => handleRemoveSet(exercise.id, set.id)} className="text-gray-600 hover:text-red-500">
                                                <X className="w-4 h-4" />
                                             </button>
                                        </div>
                                    </div>
                                ))}
                             </div>

                             <button 
                                onClick={() => handleAddSet(exercise.id)}
                                className="w-full mt-3 py-2 flex items-center justify-center gap-1 text-xs font-bold text-gray-500 hover:text-white hover:bg-white/5 rounded-lg transition"
                             >
                                <Plus className="w-3 h-3" /> Aggiungi Set
                             </button>
                        </div>
                    </div>
                ))}
                
                {stretchingExercises.length === 0 && (
                    <button 
                        onClick={() => setShowExercisePicker(true)}
                        className="w-full py-8 border-2 border-dashed border-white/10 rounded-2xl flex flex-col items-center justify-center gap-2 text-gray-500 hover:text-secondary hover:border-secondary/30 transition-all active:scale-[0.98]"
                    >
                        <Move className="w-8 h-8 opacity-50" />
                        <span className="text-sm font-bold uppercase tracking-wider">Inizia Stretching</span>
                    </button>
                )}
            </div>
        )}

        {/* ... (Rest of the component remains the same: Football, Tennis, Cycling, Running, Weightlifting, Skiing) ... */}
        
        {/* RUNNING SPECIFIC SECTIONS */}
        {isRunning && (
            <div className="space-y-4 animate-in fade-in slide-in-from-top-4 duration-500">
                
                {/* Main Stats (Distance & Pace) */}
                <section className="grid grid-cols-2 gap-4">
                    <div className="bg-card rounded-2xl p-4 border border-white/5 flex flex-col justify-between">
                        <div className="flex items-center gap-2 mb-2">
                            <Footprints className="w-4 h-4 text-secondary" />
                            <span className="text-[10px] font-bold uppercase text-gray-400">Distanza (km)</span>
                        </div>
                        <input 
                            type="number" 
                            placeholder="0.0" 
                            value={runDistance}
                            onChange={(e) => setRunDistance(e.target.value)}
                            className="w-full bg-transparent text-3xl font-extrabold text-white border-none focus:ring-0 p-0 placeholder-gray-700"
                        />
                    </div>
                    <div className="bg-card rounded-2xl p-4 border border-white/5 flex flex-col justify-between">
                        <div className="flex items-center gap-2 mb-2">
                            <Timer className="w-4 h-4 text-secondary" />
                            <span className="text-[10px] font-bold uppercase text-gray-400">Passo (min/km)</span>
                        </div>
                        <input 
                            type="text" 
                            placeholder="5:30" 
                            value={runPace}
                            onChange={(e) => setRunPace(e.target.value)}
                            className="w-full bg-transparent text-3xl font-extrabold text-white border-none focus:ring-0 p-0 placeholder-gray-700"
                        />
                    </div>
                </section>

                {/* Heart Rate Stats */}
                <section className="bg-card rounded-2xl p-4 border border-white/5">
                    <div className="flex items-center gap-2 mb-4 border-b border-white/5 pb-3">
                        <Heart className="w-4 h-4 text-red-500" />
                        <h3 className="text-xs font-bold uppercase text-gray-300">Battito Cardiaco (BPM)</h3>
                    </div>
                    <div className="grid grid-cols-2 gap-6">
                        <div>
                            <label className="text-[10px] text-gray-500 uppercase font-bold block mb-1">Medio</label>
                            <input 
                                type="number" 
                                placeholder="145" 
                                value={runAvgHr}
                                onChange={(e) => setRunAvgHr(e.target.value)}
                                className="w-full bg-surface border-none rounded-xl p-3 text-lg font-bold focus:ring-1 focus:ring-secondary"
                            />
                        </div>
                        <div>
                            <label className="text-[10px] text-gray-500 uppercase font-bold block mb-1">Massimo</label>
                            <input 
                                type="number" 
                                placeholder="185" 
                                value={runMaxHr}
                                onChange={(e) => setRunMaxHr(e.target.value)}
                                className="w-full bg-surface border-none rounded-xl p-3 text-lg font-bold focus:ring-1 focus:ring-secondary"
                            />
                        </div>
                    </div>
                </section>

                {/* Tech Specs (Elevation, Cadence) */}
                <section className="grid grid-cols-2 gap-4">
                    <div className="bg-card rounded-2xl p-4 border border-white/5">
                        <div className="flex items-center gap-2 mb-2">
                            <Mountain className="w-4 h-4 text-purple-400" />
                            <span className="text-[10px] font-bold uppercase text-gray-400">Dislivello (m)</span>
                        </div>
                        <input 
                            type="number" 
                            placeholder="0" 
                            value={runElevation}
                            onChange={(e) => setRunElevation(e.target.value)}
                            className="w-full bg-transparent text-2xl font-bold text-white border-none focus:ring-0 p-0 placeholder-gray-700"
                        />
                    </div>
                    <div className="bg-card rounded-2xl p-4 border border-white/5">
                        <div className="flex items-center gap-2 mb-2">
                            <Gauge className="w-4 h-4 text-yellow-400" />
                            <span className="text-[10px] font-bold uppercase text-gray-400">Cadenza (spm)</span>
                        </div>
                        <input 
                            type="number" 
                            placeholder="165" 
                            value={runCadence}
                            onChange={(e) => setRunCadence(e.target.value)}
                            className="w-full bg-transparent text-2xl font-bold text-white border-none focus:ring-0 p-0 placeholder-gray-700"
                        />
                    </div>
                </section>

                {/* Context (Shoes, Surface) */}
                <section className="bg-card rounded-2xl p-4 border border-white/5 space-y-4">
                    <div className="flex items-center gap-2 mb-1">
                        <Map className="w-4 h-4 text-gray-400" />
                        <h3 className="text-xs font-bold uppercase text-gray-300">Contesto</h3>
                    </div>
                    
                    <div className="space-y-1">
                        <label className="text-[10px] text-gray-500 uppercase font-bold">Scarpe</label>
                        <input 
                            type="text" 
                            placeholder="es. Nike Pegasus 40" 
                            value={runShoes}
                            onChange={(e) => setRunShoes(e.target.value)}
                            className="w-full bg-surface border-none rounded-xl p-3 text-sm focus:ring-1 focus:ring-secondary"
                        />
                    </div>

                    <div className="space-y-1">
                        <label className="text-[10px] text-gray-500 uppercase font-bold">Superficie</label>
                        <div className="relative">
                            <select 
                                value={runSurface} 
                                onChange={(e) => setRunSurface(e.target.value)}
                                className="w-full bg-surface border-none rounded-xl p-3 text-sm text-white focus:ring-1 focus:ring-secondary appearance-none"
                            >
                                <option value="">Seleziona...</option>
                                <option value="road">Strada / Asfalto</option>
                                <option value="trail">Trail / Sterrato</option>
                                <option value="track">Pista</option>
                                <option value="treadmill">Tapis Roulant</option>
                                <option value="mixed">Misto</option>
                            </select>
                            <ChevronDown className="absolute right-3 top-3.5 w-4 h-4 text-gray-500 pointer-events-none" />
                        </div>
                    </div>
                </section>
            </div>
        )}

        {/* WEIGHTLIFTING SPECIFIC SECTIONS */}
        {isWeightlifting && (
            <div className="space-y-4 animate-in fade-in slide-in-from-top-4 duration-500">
                <div className="flex items-center justify-between px-1">
                    <h3 className="text-xs font-bold uppercase tracking-widest text-gray-500">Workout Log</h3>
                    <button 
                        onClick={() => setShowExercisePicker(true)}
                        className="text-secondary text-xs font-bold uppercase flex items-center gap-1 hover:underline"
                    >
                        <Plus className="w-3 h-3" /> Add Exercise
                    </button>
                </div>

                {wlExercises.map((exercise, exIndex) => (
                    <div key={exercise.id} className="bg-card rounded-2xl border border-white/5 overflow-hidden">
                        <div className="p-4 bg-white/5 flex justify-between items-center">
                            <h3 className="font-bold text-base">{exercise.name}</h3>
                            <button onClick={() => handleRemoveExercise(exercise.id)} className="text-gray-500 hover:text-red-500 transition">
                                <Trash2 className="w-4 h-4" />
                            </button>
                        </div>
                        <div className="p-2">
                             <div className="grid grid-cols-10 gap-2 mb-2 px-2 text-[10px] font-bold uppercase text-gray-500 text-center">
                                <div className="col-span-1">Set</div>
                                <div className="col-span-3">Kg (Load)</div>
                                <div className="col-span-3">Reps</div>
                                <div className="col-span-2">% 1RM</div>
                                <div className="col-span-1"></div>
                             </div>
                             
                             <div className="space-y-2">
                                {exercise.sets.map((set, setIndex) => {
                                    const percentage = get1RMPercentage(exercise.exerciseId, set.weight);
                                    return (
                                        <div key={set.id} className="grid grid-cols-10 gap-2 items-center">
                                            <div className="col-span-1 flex justify-center">
                                                <div className="w-6 h-6 rounded-full bg-surface border border-white/10 flex items-center justify-center text-xs font-bold text-gray-400">
                                                    {setIndex + 1}
                                                </div>
                                            </div>
                                            <div className="col-span-3">
                                                <input 
                                                    type="number" 
                                                    placeholder="0"
                                                    value={set.weight}
                                                    onChange={(e) => handleUpdateSet(exercise.id, set.id, 'weight', e.target.value)}
                                                    className="w-full bg-surface border-none rounded-lg p-2 text-center text-sm font-bold focus:ring-1 focus:ring-secondary"
                                                />
                                            </div>
                                            <div className="col-span-3">
                                                <input 
                                                    type="number" 
                                                    placeholder="0"
                                                    value={set.reps}
                                                    onChange={(e) => handleUpdateSet(exercise.id, set.id, 'reps', e.target.value)}
                                                    className="w-full bg-surface border-none rounded-lg p-2 text-center text-sm font-bold focus:ring-1 focus:ring-secondary"
                                                />
                                            </div>
                                            <div className="col-span-2 text-center">
                                                {percentage ? (
                                                    <span className="text-xs font-bold text-secondary bg-secondary/10 px-2 py-1 rounded">{percentage}%</span>
                                                ) : (
                                                    <span className="text-xs text-gray-600">-</span>
                                                )}
                                            </div>
                                            <div className="col-span-1 flex justify-center">
                                                 <button onClick={() => handleRemoveSet(exercise.id, set.id)} className="text-gray-600 hover:text-red-500">
                                                    <X className="w-4 h-4" />
                                                 </button>
                                            </div>
                                        </div>
                                    );
                                })}
                             </div>

                             <button 
                                onClick={() => handleAddSet(exercise.id)}
                                className="w-full mt-3 py-2 flex items-center justify-center gap-1 text-xs font-bold text-gray-500 hover:text-white hover:bg-white/5 rounded-lg transition"
                             >
                                <Plus className="w-3 h-3" /> Add Set
                             </button>
                        </div>
                    </div>
                ))}
                
                {wlExercises.length === 0 && (
                    <button 
                        onClick={() => setShowExercisePicker(true)}
                        className="w-full py-8 border-2 border-dashed border-white/10 rounded-2xl flex flex-col items-center justify-center gap-2 text-gray-500 hover:text-secondary hover:border-secondary/30 transition-all active:scale-[0.98]"
                    >
                        <Dumbbell className="w-8 h-8 opacity-50" />
                        <span className="text-sm font-bold uppercase tracking-wider">Start Adding Exercises</span>
                    </button>
                )}
            </div>
        )}

        {/* ALPINE SKIING SPECIFIC SECTIONS */}
        {isSkiing && (
          <div className="space-y-6 animate-in fade-in slide-in-from-top-4 duration-500">
            
            {/* 1. Specialità */}
            <section className="space-y-3">
              <h3 className="text-xs font-bold uppercase tracking-widest text-gray-500 px-1">Specialità</h3>
              <div className="grid grid-cols-4 gap-2">
                {['GS', 'SL', 'SG', 'DH'].map((s) => (
                  <button 
                    key={s}
                    onClick={() => toggleSpecialty(s)}
                    className={`py-3 rounded-xl font-bold text-xs transition-all border ${
                      specialties.includes(s) 
                      ? 'bg-secondary border-secondary text-white shadow-lg shadow-secondary/20' 
                      : 'bg-card border-white/5 text-gray-400'
                    }`}
                  >
                    {s}
                  </button>
                ))}
              </div>
            </section>

            {/* 2. Volume Tecnico */}
            <section className="bg-card rounded-2xl p-4 border border-white/5 space-y-4">
               <div className="flex items-center gap-2 mb-2">
                  <Activity className="w-4 h-4 text-primary" />
                  <h3 className="text-xs font-bold uppercase text-gray-300">Campo Libero</h3>
               </div>
               <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-1">
                    <label className="text-[10px] text-gray-500 uppercase font-bold">Cambi Dir / Giro</label>
                    <input 
                      type="number" 
                      placeholder="es. 15"
                      value={freeSkiing.changes}
                      onChange={(e) => setFreeSkiing({...freeSkiing, changes: e.target.value})}
                      className="w-full bg-surface border-none rounded-lg p-3 text-sm focus:ring-1 focus:ring-primary"
                    />
                  </div>
                  <div className="space-y-1">
                    <label className="text-[10px] text-gray-500 uppercase font-bold">Giri Totali</label>
                    <input 
                      type="number" 
                      placeholder="es. 5"
                      value={freeSkiing.laps}
                      onChange={(e) => setFreeSkiing({...freeSkiing, laps: e.target.value})}
                      className="w-full bg-surface border-none rounded-lg p-3 text-sm focus:ring-1 focus:ring-primary"
                    />
                  </div>
               </div>
            </section>

            <section className="bg-card rounded-2xl p-4 border border-white/5 space-y-4">
               <div className="flex items-center gap-2 mb-2">
                  <Zap className="w-4 h-4 text-secondary" />
                  <h3 className="text-xs font-bold uppercase text-gray-300">Allenamento nei Pali</h3>
               </div>
               <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-1">
                    <label className="text-[10px] text-gray-500 uppercase font-bold">Porte per Giro</label>
                    <input 
                      type="number" 
                      placeholder="es. 40"
                      value={gatedSkiing.changes}
                      onChange={(e) => setGatedSkiing({...gatedSkiing, changes: e.target.value})}
                      className="w-full bg-surface border-none rounded-lg p-3 text-sm focus:ring-1 focus:ring-secondary"
                    />
                  </div>
                  <div className="space-y-1">
                    <label className="text-[10px] text-gray-500 uppercase font-bold">Giri Totali</label>
                    <input 
                      type="number" 
                      placeholder="es. 6"
                      value={gatedSkiing.laps}
                      onChange={(e) => setGatedSkiing({...gatedSkiing, laps: e.target.value})}
                      className="w-full bg-surface border-none rounded-lg p-3 text-sm focus:ring-1 focus:ring-secondary"
                    />
                  </div>
               </div>
            </section>

            {/* 3. Condizioni */}
            <section className="grid grid-cols-2 gap-4">
               <div className="space-y-2">
                  <label className="text-[10px] text-gray-500 uppercase font-bold px-1 flex items-center gap-1">
                    <Snowflake className="w-3 h-3" /> Neve
                  </label>
                  <div className="relative">
                    <select 
                        value={snowCondition} 
                        onChange={(e) => setSnowCondition(e.target.value)}
                        className="w-full bg-card border border-white/5 rounded-xl p-3 pr-10 text-sm text-white focus:ring-secondary appearance-none"
                    >
                        <option value="">Seleziona...</option>
                        <option value="icy">Ghiacciata</option>
                        <option value="hard">Compatta</option>
                        <option value="soft">Trasformata</option>
                        <option value="powder">Fresca</option>
                        <option value="slush">Marcia</option>
                    </select>
                    <ChevronDown className="absolute right-3 top-3.5 w-4 h-4 text-gray-500 pointer-events-none" />
                  </div>
               </div>
               <div className="space-y-2">
                  <label className="text-[10px] text-gray-500 uppercase font-bold px-1 flex items-center gap-1">
                    <Cloud className="w-3 h-3" /> Meteo
                  </label>
                  <div className="relative">
                    <select 
                        value={weatherCondition} 
                        onChange={(e) => setWeatherCondition(e.target.value)}
                        className="w-full bg-card border border-white/5 rounded-xl p-3 pr-10 text-sm text-white focus:ring-secondary appearance-none"
                    >
                        <option value="">Seleziona...</option>
                        <option value="sunny">Sole</option>
                        <option value="cloudy">Nuvole</option>
                        <option value="snowing">Neve</option>
                        <option value="foggy">Nebbia</option>
                        <option value="rainy">Pioggia</option>
                    </select>
                    <ChevronDown className="absolute right-3 top-3.5 w-4 h-4 text-gray-500 pointer-events-none" />
                  </div>
               </div>
            </section>

            {/* 5. Prove a Tempo (Multi-giro con Materiale) */}
            <section className="space-y-3">
               <div className="flex items-center justify-between px-1">
                  <h3 className="text-xs font-bold uppercase tracking-widest text-gray-500">Cronometro & Materiali</h3>
                  <Timer className="w-4 h-4 text-gray-600" />
               </div>
               
               <div className="space-y-3">
                  {timeTrials.map((trial, index) => (
                    <div key={trial.id} className="bg-card rounded-2xl border border-white/5 p-4 space-y-3 animate-in slide-in-from-right-4">
                        <div className="flex justify-between items-center">
                            <span className="text-[10px] font-bold uppercase text-secondary">Giro {index + 1}</span>
                            <button 
                                onClick={() => removeTrial(trial.id)}
                                className="p-1.5 bg-white/5 rounded-lg text-gray-500 hover:text-red-500 hover:bg-red-500/10 transition-colors"
                            >
                                <Trash2 className="w-4 h-4" />
                            </button>
                        </div>
                        <div className="grid grid-cols-12 gap-3">
                            <div className="col-span-4 space-y-1">
                                <label className="text-[9px] text-gray-500 uppercase font-bold px-1">Tempo</label>
                                <div className="relative">
                                    <input 
                                        type="text" 
                                        placeholder="es. 45.2" 
                                        value={trial.time}
                                        onChange={(e) => updateTrial(trial.id, 'time', e.target.value)}
                                        className="w-full bg-surface border-none rounded-xl p-3 text-sm font-mono font-bold text-white focus:ring-1 focus:ring-secondary"
                                    />
                                </div>
                            </div>
                            <div className="col-span-8 space-y-1">
                                <label className="text-[9px] text-gray-500 uppercase font-bold px-1">Materiale Usato</label>
                                <div className="relative">
                                    <Package className="absolute left-3 top-3 w-4 h-4 text-gray-600" />
                                    <input 
                                        type="text" 
                                        placeholder="es. Sci Gara 1 / Sciolina HF" 
                                        value={trial.material}
                                        onChange={(e) => updateTrial(trial.id, 'material', e.target.value)}
                                        className="w-full bg-surface border-none rounded-xl p-3 pl-9 text-xs text-white focus:ring-1 focus:ring-secondary"
                                    />
                                </div>
                            </div>
                        </div>
                    </div>
                  ))}

                  <button 
                    onClick={addTrial}
                    className="w-full py-4 border-2 border-dashed border-white/10 rounded-2xl flex items-center justify-center gap-2 text-gray-500 hover:text-secondary hover:border-secondary/30 transition-all active:scale-[0.98]"
                  >
                    <Plus className="w-5 h-5" />
                    <span className="text-sm font-bold uppercase tracking-wider">Aggiungi Giro Crono</span>
                  </button>
               </div>
            </section>
          </div>
        )}

        {/* 4. Monitoraggio Dolore (FLAG BUTTONS) - Shared Section */}
        <section className="space-y-3">
          <h3 className="text-xs font-bold uppercase tracking-widest text-gray-500 px-1">Report Dolore</h3>
          <div className="bg-card rounded-2xl p-4 border border-white/5 space-y-4">
            <p className="text-[11px] text-gray-400 font-medium">Seleziona le aree dove hai avvertito fastidio:</p>
            <div className="grid grid-cols-2 gap-3">
              {[
                { id: 'Back (Schiena)', label: 'Schiena' },
                { id: 'Knee (Ginocchio)', label: 'Ginocchio' },
                { id: 'Feet (Piedi)', label: 'Piedi' },
                { id: 'Other (Altro)', label: 'Altro' }
              ].map((zone) => (
                <button 
                  key={zone.id}
                  onClick={() => togglePainZone(zone.id)}
                  className={`flex items-center justify-between p-3 rounded-xl border transition-all duration-200 ${
                    painZones.includes(zone.id) 
                    ? 'bg-red-500/10 border-red-500 text-red-500 shadow-lg shadow-red-500/10' 
                    : 'bg-surface border-white/5 text-gray-400'
                  }`}
                >
                  <span className="text-xs font-bold">{zone.label}</span>
                  <div className={`w-5 h-5 rounded-full flex items-center justify-center transition-colors ${
                    painZones.includes(zone.id) ? 'bg-red-500 text-white' : 'bg-white/5'
                  }`}>
                    {painZones.includes(zone.id) ? (
                        <AlertTriangle className="w-3 h-3" />
                    ) : (
                        <div className="w-1.5 h-1.5 rounded-full bg-gray-700" />
                    )}
                  </div>
                </button>
              ))}
            </div>
            {painZones.includes('Other (Altro)') && (
              <textarea 
                value={otherPain}
                onChange={(e) => setOtherPain(e.target.value)}
                placeholder="Specifica la zona o il tipo di dolore..."
                className="w-full bg-surface border-none rounded-xl p-3 text-sm text-white h-20 resize-none focus:ring-1 focus:ring-red-500 animate-in fade-in zoom-in-95"
              />
            )}
          </div>
        </section>

        {/* Intensità - Standard */}
        <section>
             <div className="flex items-center gap-3 mb-4">
                <div className="w-1 h-4 bg-orange-500 rounded-full"></div>
                <h2 className="text-xs font-bold uppercase tracking-widest text-gray-400">Intensità Percepita (RPE)</h2>
            </div>
            
            <div className="bg-card p-6 rounded-2xl border border-white/5">
                <div className="flex justify-between items-end mb-6">
                    <div>
                        <p className="text-[10px] font-bold text-gray-500 uppercase mb-1">Quanto è stato duro?</p>
                        <p className={`text-2xl font-bold ${getEffortColor(effort)} transition-colors`}>{getEffortLabel(effort)}</p>
                    </div>
                    <div className="text-4xl font-extrabold">{effort}<span className="text-lg text-gray-500 font-medium">/10</span></div>
                </div>

                <div className="relative h-6 flex items-center">
                    <input 
                        type="range" 
                        min="1" 
                        max="10" 
                        step="1"
                        value={effort} 
                        onChange={(e) => setEffort(parseInt(e.target.value))}
                        className="w-full h-2 bg-surface rounded-lg appearance-none cursor-pointer focus:outline-none z-10 relative"
                        style={{
                            background: `linear-gradient(to right, ${fillColor} 0%, ${fillColor} ${fillPercent}%, #181A1F ${fillPercent}%, #181A1F 100%)`
                        }}
                    />
                     <style>{`
                        input[type=range]::-webkit-slider-thumb {
                            -webkit-appearance: none;
                            height: 24px;
                            width: 24px;
                            border-radius: 50%;
                            background: white;
                            cursor: pointer;
                            margin-top: -8px;
                            box-shadow: 0 0 10px rgba(0,0,0,0.5);
                            border: 2px solid #13A4EC;
                        }
                     `}</style>
                </div>
            </div>
        </section>

      </div>

      {/* Tasto Salva */}
      <div className="fixed bottom-0 left-0 right-0 p-4 bg-gradient-to-t from-background via-background to-transparent z-40 pb-6 border-t border-white/5 backdrop-blur-sm">
        <button onClick={handleSave} className="w-full py-4 rounded-full bg-secondary text-white text-sm font-bold uppercase tracking-widest shadow-lg shadow-secondary/25 hover:bg-sky-500 active:scale-[0.98] transition-all">
            {initialSession ? 'Aggiorna Sessione' : 'Salva Sessione Allenamento'}
        </button>
      </div>
    </div>
  );
};

export default AddTraining;
