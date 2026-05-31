
import React, { useState, useMemo } from 'react';
import { Calendar as CalendarIcon, Users, Plus, MapPin, CheckCircle, User, ClipboardList, LayoutList, CalendarDays, ChevronLeft, ChevronRight, X, Info, Activity, Trophy, Zap, Search, Filter, SlidersHorizontal, RotateCcw, ArrowLeft, TrendingUp, Dumbbell, Snowflake, Clock, BarChart3, Scale, Ruler, Home as HomeIcon, ChevronDown, Timer, CheckSquare, Square } from 'lucide-react';
import { ViewState, UserProfile, Team, CalendarEvent, TrainingSession, JumpLog, PRLog } from '../types';
import { WeightChart, HeightChart, JumpChart } from '../components/Charts'; 
import Profile from './Profile';

interface Props {
  setView: (view: ViewState) => void;
  userProfile: UserProfile;
  teams: Team[];
  events: CalendarEvent[]; 
  onLogout: () => void;
  onEventSelect: (eventId: string) => void; 
  onCreateEvent: (date: string) => void; 
  onSyncSessions: (event: CalendarEvent) => void; 
  onSaveProfile: (profile: UserProfile) => void;
}

type CoachTab = 'home' | 'reports' | 'workouts' | 'profile';
type CalendarMode = 'week' | 'month';
type SortMode = 'hours' | 'changes';
type ReportViewMode = 'overview' | 'session_detail' | 'chart_detail';
type ChartType = 'weight' | 'height';
type TimeRange = '1M' | '3M' | '6M' | '1Y' | 'ALL';

// --- SUB-COMPONENTS ---

const SessionDetailView: React.FC<{ session: TrainingSession; onBack: () => void }> = ({ session, onBack }) => {
    const sportName = session.sportId.replace('_', ' ');
    return (
        <div className="bg-background h-full flex flex-col animate-in slide-in-from-right duration-300">
            <div className="sticky top-0 bg-background/95 backdrop-blur z-20 border-b border-white/5 p-4 flex items-center gap-4">
                <button onClick={onBack} className="w-10 h-10 rounded-full bg-white/5 flex items-center justify-center hover:bg-white/10">
                    <ArrowLeft className="w-5 h-5" />
                </button>
                <div>
                    <h2 className="font-bold text-lg capitalize">{sportName}</h2>
                    <p className="text-xs text-gray-400">{session.date} • {session.startTime}</p>
                </div>
            </div>

            <div className="p-4 space-y-6 overflow-y-auto pb-24 flex-1">
                {/* Summary Card */}
                <div className="bg-card border border-white/5 rounded-2xl p-4 flex justify-between items-center">
                    <div className="text-center">
                        <p className="text-xs text-gray-500 uppercase font-bold">Durata</p>
                        <p className="text-xl font-bold">{session.duration}</p>
                    </div>
                    <div className="w-px h-8 bg-white/10"></div>
                    <div className="text-center">
                        <p className="text-xs text-gray-500 uppercase font-bold">RPE</p>
                        <p className={`text-xl font-bold ${session.effort > 8 ? 'text-red-500' : 'text-secondary'}`}>{session.effort}/10</p>
                    </div>
                    <div className="w-px h-8 bg-white/10"></div>
                    <div className="text-center">
                        <p className="text-xs text-gray-500 uppercase font-bold">Ora Fine</p>
                        <p className="text-xl font-bold">{session.endTime}</p>
                    </div>
                </div>

                {/* Sport Specific Details */}
                {session.sportId === 'alpine_skiing' && (
                    <div className="space-y-4">
                        <div className="bg-card border border-white/5 rounded-2xl p-4">
                            <h3 className="font-bold text-sm mb-3 flex items-center gap-2"><Snowflake className="w-4 h-4 text-secondary"/> Dettagli Neve</h3>
                            <div className="grid grid-cols-2 gap-4 text-sm">
                                <div>
                                    <span className="text-gray-500 block text-xs uppercase">Condizione</span>
                                    <span className="font-semibold">{session.details?.snowCondition || '-'}</span>
                                </div>
                                <div>
                                    <span className="text-gray-500 block text-xs uppercase">Meteo</span>
                                    <span className="font-semibold">{session.details?.weatherCondition || '-'}</span>
                                </div>
                            </div>
                        </div>
                        
                        {(session.details?.gatedSkiing?.laps || session.details?.freeSkiing?.laps) && (
                            <div className="bg-card border border-white/5 rounded-2xl p-4">
                                <h3 className="font-bold text-sm mb-3 flex items-center gap-2"><Activity className="w-4 h-4 text-orange-500"/> Volume</h3>
                                {session.details?.gatedSkiing?.laps && (
                                    <div className="flex justify-between items-center mb-2">
                                        <span className="text-gray-400">Pali (Giri)</span>
                                        <span className="font-bold">{session.details.gatedSkiing.laps} giri x {session.details.gatedSkiing.changes} porte</span>
                                    </div>
                                )}
                                {session.details?.freeSkiing?.laps && (
                                    <div className="flex justify-between items-center">
                                        <span className="text-gray-400">Campo Libero</span>
                                        <span className="font-bold">{session.details.freeSkiing.laps} giri</span>
                                    </div>
                                )}
                            </div>
                        )}
                    </div>
                )}

                {session.sportId === 'weightlifting' && session.details?.weightlifting && (
                    <div className="space-y-3">
                        <h3 className="font-bold text-sm uppercase text-gray-500">Scheda Allenamento</h3>
                        {session.details.weightlifting.exercises.map((ex, idx) => (
                            <div key={idx} className="bg-card border border-white/5 rounded-2xl p-4">
                                <h4 className="font-bold text-base mb-3 text-secondary">{ex.name}</h4>
                                <div className="space-y-2">
                                    {ex.sets.map((set, sIdx) => (
                                        <div key={sIdx} className="flex justify-between items-center text-sm border-b border-white/5 last:border-0 pb-1 last:pb-0">
                                            <span className="text-gray-500 w-8">Set {sIdx + 1}</span>
                                            <span className="font-mono font-bold">{set.weight} kg</span>
                                            <span className="text-gray-400">x {set.reps} reps</span>
                                            {set.completed && <CheckCircle className="w-3 h-3 text-green-500"/>}
                                        </div>
                                    ))}
                                </div>
                            </div>
                        ))}
                    </div>
                )}

                {session.sportId.includes('running') && session.details?.running && (
                    <div className="bg-card border border-white/5 rounded-2xl p-4 space-y-4">
                        <h3 className="font-bold text-sm flex items-center gap-2"><Timer className="w-4 h-4 text-blue-400"/> Stats Corsa</h3>
                        <div className="grid grid-cols-2 gap-4">
                            <div>
                                <p className="text-xs text-gray-500 uppercase">Distanza</p>
                                <p className="font-bold text-lg">{session.details.running.distance} km</p>
                            </div>
                            <div>
                                <p className="text-xs text-gray-500 uppercase">Passo Medio</p>
                                <p className="font-bold text-lg">{session.details.running.avgPace} /km</p>
                            </div>
                            <div>
                                <p className="text-xs text-gray-500 uppercase">Dislivello</p>
                                <p className="font-bold text-lg">{session.details.running.elevation} m</p>
                            </div>
                            <div>
                                <p className="text-xs text-gray-500 uppercase">FC Media</p>
                                <p className="font-bold text-lg">{session.details.running.avgHr} bpm</p>
                            </div>
                        </div>
                    </div>
                )}
            </div>
        </div>
    );
};

const ChartDetailView: React.FC<{ type: ChartType; data: any[]; onBack: () => void }> = ({ type, data, onBack }) => {
    const [chartTimeRange, setChartTimeRange] = useState<TimeRange>('6M');

    const filteredData = useMemo(() => {
        const now = new Date();
        let cutoff = new Date();
        switch(chartTimeRange) {
            case '1M': cutoff.setMonth(now.getMonth() - 1); break;
            case '3M': cutoff.setMonth(now.getMonth() - 3); break;
            case '6M': cutoff.setMonth(now.getMonth() - 6); break;
            case '1Y': cutoff.setFullYear(now.getFullYear() - 1); break;
            case 'ALL': cutoff = new Date(0); break;
        }
        return data.filter(d => new Date(d.date) >= cutoff);
    }, [data, chartTimeRange]);

    return (
        <div className="bg-background h-full flex flex-col animate-in fade-in duration-300">
            <div className="p-4 flex items-center justify-between border-b border-white/5">
                <button onClick={onBack} className="flex items-center gap-2 text-gray-400 hover:text-white">
                    <ArrowLeft className="w-5 h-5" /> Indietro
                </button>
                <h2 className="font-bold text-lg">{type === 'weight' ? 'Andamento Peso' : 'Andamento Altezza'}</h2>
            </div>
            
            <div className="p-4 flex justify-center gap-2">
                {(['1M', '3M', '6M', '1Y', 'ALL'] as TimeRange[]).map(r => (
                    <button 
                      key={r}
                      onClick={() => setChartTimeRange(r)}
                      className={`px-4 py-1.5 rounded-full text-xs font-bold transition-all ${chartTimeRange === r ? 'bg-secondary text-white' : 'bg-white/5 text-gray-400'}`}
                    >
                        {r}
                    </button>
                ))}
            </div>

            <div className="flex-1 p-4 overflow-y-auto">
                <div className="h-64 w-full bg-card rounded-2xl border border-white/5 p-4 flex items-center justify-center">
                    {filteredData.length === 0 ? (
                        <div className="text-center">
                            <p className="text-gray-400 text-sm">Nessun dato registrato in questo periodo.</p>
                            {chartTimeRange !== 'ALL' && (
                                <button 
                                    onClick={() => setChartTimeRange('ALL')}
                                    className="mt-3 text-xs text-secondary hover:underline font-bold"
                                >
                                    Mostra tutti i dati
                                </button>
                            )}
                        </div>
                    ) : type === 'weight' ? (
                        <WeightChart data={filteredData.map(d => ({...d, date: new Date(d.date).toLocaleDateString('it-IT', {day:'2-digit', month:'short'}), bodyFat: 15}))} />
                    ) : (
                        <HeightChart data={filteredData.map(d => ({...d, date: new Date(d.date).toLocaleDateString('it-IT', {month:'short'})}))} />
                    )}
                </div>
                
                {/* Detailed List */}
                <div className="mt-6 space-y-2 pb-24">
                    <h3 className="text-xs font-bold uppercase text-gray-500 mb-2">Cronologia</h3>
                    {filteredData.slice().reverse().map((d, i) => (
                        <div key={i} className="flex justify-between items-center p-3 bg-white/5 rounded-xl">
                            <span className="text-sm text-gray-300">{d.date}</span>
                            <span className="font-bold font-mono text-white">
                                {type === 'weight' ? d.weight : d.height} <span className="text-xs text-gray-500">{type === 'weight' ? 'kg' : 'cm'}</span>
                            </span>
                        </div>
                    ))}
                </div>
            </div>
        </div>
    );
};

const CalendarView: React.FC<{ 
    events: CalendarEvent[]; 
    teams: Team[]; 
    onEventSelect: (id: string) => void;
    onCreateEvent: (date: string) => void;
    selectedDate: Date;
    onDateChange: (date: Date) => void;
}> = ({ events, teams, onEventSelect, onCreateEvent, selectedDate, onDateChange }) => {
    const [calendarMode, setCalendarMode] = useState<CalendarMode>('week');
    const selectedDateStr = selectedDate.toISOString().split('T')[0];

    const dailyEvents = events.filter(e => e.date === selectedDateStr).sort((a,b) => a.startTime.localeCompare(b.startTime));

    const weekDates = useMemo(() => {
        const dates = [];
        const curr = new Date(selectedDate);
        const day = curr.getDay();
        const diff = curr.getDate() - day + (day === 0 ? -6 : 1);
        const monday = new Date(curr.setDate(diff));
        for (let i = 0; i < 7; i++) {
            const d = new Date(monday);
            d.setDate(monday.getDate() + i);
            dates.push(d);
        }
        return dates;
    }, [selectedDate]);

    const monthDays = useMemo(() => {
        const year = selectedDate.getFullYear();
        const month = selectedDate.getMonth();
        const lastDay = new Date(year, month + 1, 0);
        const days = [];
        const startDay = new Date(year, month, 1).getDay() === 0 ? 6 : new Date(year, month, 1).getDay() - 1; 
        for(let i = 0; i < startDay; i++) days.push(null);
        for(let i = 1; i <= lastDay.getDate(); i++) days.push(new Date(year, month, i));
        return days;
    }, [selectedDate]);

    const handleDateChange = (direction: 'prev' | 'next') => {
        const newDate = new Date(selectedDate);
        if (calendarMode === 'week') {
            newDate.setDate(selectedDate.getDate() + (direction === 'next' ? 7 : -7));
        } else {
            newDate.setMonth(selectedDate.getMonth() + (direction === 'next' ? 1 : -1));
        }
        onDateChange(newDate);
    };

    return (
        <div className="flex flex-col h-full animate-in fade-in slide-in-from-right-4 duration-300">
            <div className="p-4 space-y-4">
                <div className="flex justify-between items-center">
                    <h2 className="text-xl font-bold">Calendario</h2>
                    <div className="flex bg-surface rounded-lg p-1 border border-white/5">
                        <button 
                            onClick={() => setCalendarMode('week')}
                            className={`px-3 py-1.5 rounded-md text-xs font-bold transition-all ${calendarMode === 'week' ? 'bg-secondary text-white shadow' : 'text-gray-500 hover:text-white'}`}
                        >
                            Settimana
                        </button>
                        <button 
                            onClick={() => setCalendarMode('month')}
                            className={`px-3 py-1.5 rounded-md text-xs font-bold transition-all ${calendarMode === 'month' ? 'bg-secondary text-white shadow' : 'text-gray-500 hover:text-white'}`}
                        >
                            Mese
                        </button>
                    </div>
                </div>

                <div className="bg-card border border-white/5 rounded-2xl p-4 shadow-lg">
                    <div className="flex justify-between items-center mb-4">
                        <button onClick={() => handleDateChange('prev')} className="p-2 hover:bg-white/5 rounded-full"><ChevronLeft className="w-5 h-5 text-gray-400" /></button>
                        <span className="font-bold text-lg capitalize">
                            {selectedDate.toLocaleDateString('it-IT', { month: 'long', year: 'numeric' })}
                        </span>
                        <button onClick={() => handleDateChange('next')} className="p-2 hover:bg-white/5 rounded-full"><ChevronRight className="w-5 h-5 text-gray-400" /></button>
                    </div>

                    {calendarMode === 'week' ? (
                        <div className="grid grid-cols-7 gap-1">
                            {weekDates.map((date, i) => {
                                const isSelected = date.toDateString() === selectedDate.toDateString();
                                const isToday = date.toDateString() === new Date().toDateString();
                                const hasEvent = events.some(e => e.date === date.toISOString().split('T')[0]);
                                return (
                                    <button 
                                        key={i} 
                                        onClick={() => onDateChange(date)}
                                        className={`flex flex-col items-center p-2 rounded-xl transition-all ${isSelected ? 'bg-secondary text-white shadow-lg scale-105' : 'hover:bg-white/5'}`}
                                    >
                                        <span className={`text-[10px] font-bold uppercase mb-1 ${isSelected ? 'text-white/80' : 'text-gray-500'}`}>
                                            {date.toLocaleDateString('it-IT', { weekday: 'short' }).slice(0, 3)}
                                        </span>
                                        <div className={`w-8 h-8 rounded-full flex items-center justify-center font-bold text-sm ${isToday && !isSelected ? 'bg-white/10 text-white' : ''}`}>
                                            {date.getDate()}
                                        </div>
                                        <div className={`w-1.5 h-1.5 rounded-full mt-1 ${hasEvent ? (isSelected ? 'bg-white' : 'bg-secondary') : 'bg-transparent'}`}></div>
                                    </button>
                                );
                            })}
                        </div>
                    ) : (
                        <div className="grid grid-cols-7 gap-1 text-center">
                            {['L', 'M', 'M', 'G', 'V', 'S', 'D'].map(d => (
                                <span key={d} className="text-[10px] font-bold text-gray-500 py-2">{d}</span>
                            ))}
                            {monthDays.map((date, i) => {
                                if (!date) return <div key={i}></div>;
                                const isSelected = date.toDateString() === selectedDate.toDateString();
                                const hasEvent = events.some(e => e.date === date.toISOString().split('T')[0]);
                                return (
                                    <button 
                                        key={i}
                                        onClick={() => onDateChange(date)}
                                        className={`h-9 rounded-lg flex flex-col items-center justify-center text-xs font-bold relative ${isSelected ? 'bg-secondary text-white' : 'hover:bg-white/5'}`}
                                    >
                                        {date.getDate()}
                                        {hasEvent && <div className={`absolute bottom-1 w-1 h-1 rounded-full ${isSelected ? 'bg-white' : 'bg-secondary'}`}></div>}
                                    </button>
                                );
                            })}
                        </div>
                    )}
                </div>
            </div>

            <div className="flex-1 bg-surface/30 rounded-t-3xl p-6 overflow-y-auto pb-24 border-t border-white/5">
                <div className="flex justify-between items-center mb-4">
                    <h3 className="font-bold text-lg flex items-center gap-2">
                        <CalendarIcon className="w-5 h-5 text-gray-400" />
                        Programma {selectedDate.getDate() === new Date().getDate() ? 'di Oggi' : `del ${selectedDate.getDate()}`}
                    </h3>
                    <span className="text-xs font-bold bg-white/5 px-2 py-1 rounded text-gray-400">{dailyEvents.length} Eventi</span>
                </div>

                <div className="space-y-4">
                    {dailyEvents.length > 0 ? (
                        dailyEvents.map(event => {
                            const team = teams.find(t => t.id === event.teamId);
                            return (
                                <div 
                                    key={event.id}
                                    onClick={() => onEventSelect(event.id)}
                                    className="bg-card border border-white/5 p-4 rounded-2xl relative overflow-hidden group cursor-pointer hover:border-white/20 transition active:scale-[0.98]"
                                >
                                    <div className={`absolute left-0 top-0 bottom-0 w-1 ${event.type === 'match' ? 'bg-orange-500' : event.sportCategory === 'dryland' ? 'bg-amber-500' : 'bg-secondary'}`}></div>
                                    <div className="pl-3">
                                        <div className="flex justify-between items-start">
                                            <div className="flex items-center gap-2 mb-1">
                                                <span className="text-xs font-bold text-gray-500 uppercase">{event.startTime} - {event.endTime}</span>
                                                {event.type === 'match' ? (
                                                    <span className="bg-orange-500/20 text-orange-500 text-[9px] font-bold px-1.5 py-0.5 rounded uppercase">Gara</span>
                                                ) : event.sportCategory === 'dryland' ? (
                                                    <span className="bg-amber-500/20 text-amber-500 text-[9px] font-bold px-1.5 py-0.5 rounded uppercase flex items-center gap-1">
                                                        <Dumbbell className="w-2.5 h-2.5" /> Atletico
                                                    </span>
                                                ) : (
                                                    <span className="bg-sky-500/20 text-sky-400 text-[9px] font-bold px-1.5 py-0.5 rounded uppercase flex items-center gap-1">
                                                        <Snowflake className="w-2.5 h-2.5" /> Sci
                                                    </span>
                                                )}
                                            </div>
                                            {team && <span className="text-[10px] font-bold text-gray-600 bg-white/5 px-2 py-0.5 rounded">{team.name}</span>}
                                        </div>
                                        <h4 className="font-bold text-base mb-1">{event.title}</h4>
                                        <div className="flex items-center gap-3 text-xs text-gray-400">
                                            {event.location && <span className="flex items-center gap-1"><MapPin className="w-3 h-3" /> {event.location}</span>}
                                            {event.attendees && <span className="flex items-center gap-1"><Users className="w-3 h-3" /> {event.attendees.filter(a => a.isPresent).length} Presenti</span>}
                                        </div>
                                    </div>
                                    <ChevronRight className="absolute right-4 top-1/2 -translate-y-1/2 text-gray-600 w-5 h-5 group-hover:text-white transition-colors" />
                                </div>
                            );
                        })
                    ) : (
                        <div className="text-center py-10 opacity-50">
                            <p className="text-gray-500 text-sm">Nessun evento in programma.</p>
                            <button 
                                onClick={() => onCreateEvent(selectedDateStr)}
                                className="mt-4 text-secondary text-sm font-bold flex items-center justify-center gap-1 hover:underline mx-auto"
                            >
                                <Plus className="w-4 h-4" /> Crea Evento
                            </button>
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
};

// ... other Interface ...
// Extended Athlete Interface for Reports (Added)
interface AthleteStats {
    id: string;
    name: string;
    teamId: string;
    avatarUrl?: string;
    attendancePct: number;
    skiAttendancePct: number;
    drylandAttendancePct: number;
    skiEventsCount: number;
    skiAttendedCount: number;
    drylandEventsCount: number;
    drylandAttendedCount: number;
    totalHours: number; 
    nonSkiHours: number; 
    totalChanges: number;
    changesBySpec: { SL: number; GS: number; SG: number; DH: number };
    weightTrend: { date: string; weight: number }[];
    heightTrend: { date: string; height: number }[];
    recentSessions: TrainingSession[];
    jumpStats: Record<string, number>; 
    prStats: Record<string, number>;   
}

const CoachDashboard: React.FC<Props> = ({ setView, userProfile, teams, events, onLogout, onEventSelect, onCreateEvent, onSyncSessions, onSaveProfile }) => {
  const [activeTab, setActiveTab] = useState<CoachTab>('home');
  const [selectedDate, setSelectedDate] = useState(new Date());
  const selectedDateStr = selectedDate.toISOString().split('T')[0];
  const [notificationSent, setNotificationSent] = useState<string | null>(null);

  // --- WORKOUTS FILTER STATE ---
  const [workoutSearch, setWorkoutSearch] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [filterStartDate, setFilterStartDate] = useState('');
  const [filterEndDate, setFilterEndDate] = useState('');
  const [filterLocation, setFilterLocation] = useState('');
  const [filterSpecialty, setFilterSpecialty] = useState('');

  // --- REPORT STATE ---
  const [reportSearch, setReportSearch] = useState('');
  const [selectedAthleteId, setSelectedAthleteId] = useState<string | null>(null);
  const [reportSort, setReportSort] = useState<SortMode>('hours');
  
  // Report Drill-down States
  const [reportViewMode, setReportViewMode] = useState<ReportViewMode>('overview');
  const [selectedSessionId, setSelectedSessionId] = useState<string | null>(null);
  const [selectedChartType, setSelectedChartType] = useState<ChartType>('weight');

  // --- WORKOUT FILTER LOGIC ---
  const filteredWorkouts = useMemo(() => {
      return events.filter(event => {
          const team = teams.find(t => t.id === event.teamId);
          const matchesSearch = workoutSearch === '' || event.title.toLowerCase().includes(workoutSearch.toLowerCase()) || team?.name.toLowerCase().includes(workoutSearch.toLowerCase()) || (event.notes && event.notes.toLowerCase().includes(workoutSearch.toLowerCase()));
          const matchesStart = filterStartDate ? event.date >= filterStartDate : true;
          const matchesEnd = filterEndDate ? event.date <= filterEndDate : true;
          const matchesLocation = filterLocation ? event.location?.toLowerCase().includes(filterLocation.toLowerCase()) : true;
          const matchesSpecialty = filterSpecialty ? event.technicalDetails?.specialties?.includes(filterSpecialty) : true;
          return matchesSearch && matchesStart && matchesEnd && matchesLocation && matchesSpecialty;
      }).sort((a,b) => new Date(b.date).getTime() - new Date(a.date).getTime());
  }, [events, teams, workoutSearch, filterStartDate, filterEndDate, filterLocation, filterSpecialty]);

  const resetFilters = () => {
      setWorkoutSearch(''); setFilterStartDate(''); setFilterEndDate(''); setFilterLocation(''); setFilterSpecialty(''); setShowFilters(false);
  };
  const activeFiltersCount = [filterStartDate, filterEndDate, filterLocation, filterSpecialty].filter(Boolean).length;

  // --- REPORT DATA GENERATION ---
  const globalStats = useMemo(() => {
      const totalDays = new Set(events.map(e => e.date)).size;
      const breakdown: Record<string, number> = {};
      events.forEach(e => {
          e.technicalDetails?.specialties?.forEach(s => {
              breakdown[s] = (breakdown[s] || 0) + 1;
          });
          if (e.type === 'match') breakdown['Gara'] = (breakdown['Gara'] || 0) + 1;
      });
      return { totalDays, breakdown };
  }, [events]);

  const athleteStats: AthleteStats[] = useMemo(() => {
      // Base athletes (In real app, this comes from a Users collection)
      const baseAthletes = [
          { id: '1', name: 'Sarah Jenkins', teamId: 't1' },
          { id: '2', name: 'Mike Thompson', teamId: 't1' },
          { id: '3', name: 'Alex Rivera', teamId: 't1' },
          { id: '4', name: 'Jessica Lee', teamId: 't1' },
          { id: '5', name: 'Davide Rossi', teamId: 't1' },
          { id: '6', name: 'Marco Verratti', teamId: 't2' }, // Different team
          { id: '7', name: 'Anna K.', teamId: 't2' },
      ];

      return baseAthletes.map(a => {
          let attendedEvents = 0;
          let skiChanges: { SL: number; GS: number; SG: number; DH: number } = { SL: 0, GS: 0, SG: 0, DH: 0 };
          let skiHours = 0;
          let totalChanges = 0;
          const multiplier = 0.8 + Math.random() * 0.4; 

          let skiEventsCount = 0;
          let skiAttendedCount = 0;
          let drylandEventsCount = 0;
          let drylandAttendedCount = 0;

          events.forEach(e => {
              if (e.teamId === a.teamId) {
                  const isDryland = e.sportCategory === 'dryland';
                  if (isDryland) {
                      drylandEventsCount++;
                  } else {
                      skiEventsCount++;
                  }

                  const isPresent = e.attendees?.find(at => at.id === a.id)?.isPresent ?? true; 
                  if (isPresent) {
                      attendedEvents++;
                      if (isDryland) {
                          drylandAttendedCount++;
                      } else {
                          skiAttendedCount++;
                          const [h1, m1] = e.startTime.split(':').map(Number);
                          const [h2, m2] = e.endTime.split(':').map(Number);
                          const duration = (h2 + m2/60) - (h1 + m1/60);
                          skiHours += duration > 0 ? duration : 2;

                          if (e.technicalDetails) {
                              const details = e.technicalDetails;
                              const laps = parseInt(details.gatedSkiing.laps || '0') || 0;
                              const turns = parseInt(details.gatedSkiing.changes || '0') || 0;
                              const sessionChanges = laps * turns * multiplier; 
                              totalChanges += Math.floor(sessionChanges);
                              
                              if (details.specialties && details.specialties.length > 0) {
                                  details.specialties.forEach(s => {
                                     if (s === 'SL' || s === 'GS' || s === 'SG' || s === 'DH') {
                                         skiChanges[s] += Math.floor(sessionChanges / details.specialties.length);
                                     }
                                  });
                              }
                          }
                      }
                  }
              }
          });

          const skiAttendancePct = skiEventsCount > 0 ? Math.round((skiAttendedCount / skiEventsCount) * 100) : 100;
          const drylandAttendancePct = drylandEventsCount > 0 ? Math.round((drylandAttendedCount / drylandEventsCount) * 100) : 100;

          const nonSkiHours = Math.floor(attendedEvents * 1.5 * multiplier); 
          const initialSessions: TrainingSession[] = [];
          
          events.filter(e => e.teamId === a.teamId).slice(0, 5).forEach(e => {
              initialSessions.push({
                  id: `sess-${e.id}`,
                  sportId: 'alpine_skiing',
                  date: e.date,
                  startTime: e.startTime,
                  endTime: e.endTime,
                  duration: '3h',
                  effort: Math.floor(Math.random() * 4) + 6,
                  details: { 
                      specialties: e.technicalDetails?.specialties,
                      gatedSkiing: e.technicalDetails?.gatedSkiing,
                      freeSkiing: e.technicalDetails?.freeSkiing,
                      snowCondition: e.technicalDetails?.snowCondition,
                      weatherCondition: e.technicalDetails?.weatherCondition
                  }
              });
          });

          initialSessions.push({
              id: 'gym-1', sportId: 'weightlifting', date: '2023-11-01', startTime: '16:00', endTime: '17:30', duration: '1h 30m', effort: 8,
              details: { 
                  weightlifting: { 
                      exercises: [
                          {id: '1', name: 'Back Squat', exerciseId: 'back_squat', sets: [{id:'s1', reps:'8', weight:'90', completed:true}, {id:'s2', reps:'8', weight:'95', completed:true}, {id:'s3', reps:'6', weight:'100', completed:true}]},
                          {id: '2', name: 'Bench Press', exerciseId: 'bench_press', sets: [{id:'s4', reps:'10', weight:'60', completed:true}, {id:'s5', reps:'10', weight:'60', completed:true}]}
                      ] 
                  } 
              }
          });
          initialSessions.push({
              id: 'run-1', sportId: 'running_road', date: '2023-10-28', startTime: '07:00', endTime: '08:00', duration: '1h', effort: 7,
              details: { running: { distance: '10.5', avgPace: '5:40', avgHr: '145', maxHr: '170', elevation: '120', cadence: '170', shoes: 'Nike Pegasus', surface: 'Road' } }
          });

          const chartHistory = [];
          const now = new Date();
          for(let i=11; i>=0; i--) {
              const d = new Date(now.getFullYear(), now.getMonth()-i, 1);
              const dateStr = d.toISOString().split('T')[0];
              chartHistory.push({
                  date: dateStr,
                  weight: 70 + (Math.random() * 2 - 1),
                  height: 175 + (i < 6 ? 0.5 : 0) 
              });
          }

          return {
              id: a.id,
              name: a.name,
              teamId: a.teamId,
              attendancePct: Math.round((attendedEvents / (events.filter(e => e.teamId === a.teamId).length || 1)) * 100),
              skiAttendancePct,
              drylandAttendancePct,
              skiEventsCount,
              skiAttendedCount,
              drylandEventsCount,
              drylandAttendedCount,
              totalHours: parseFloat((skiHours + nonSkiHours).toFixed(1)),
              nonSkiHours: parseFloat(nonSkiHours.toFixed(1)),
              totalChanges,
              changesBySpec: skiChanges,
              weightTrend: chartHistory.map(x => ({date: x.date, weight: x.weight})),
              heightTrend: chartHistory.map(x => ({date: x.date, height: x.height})), 
              recentSessions: initialSessions.sort((x,y) => new Date(y.date).getTime() - new Date(x.date).getTime()),
              jumpStats: {
                  'squat_jump': 35 + Math.floor(Math.random()*10),
                  'cm_jump': 40 + Math.floor(Math.random()*10),
                  'drop_jump': 30 + Math.floor(Math.random()*10)
              },
              prStats: {
                  'Back Squat': 120 + Math.floor(Math.random()*40),
                  'Bench Press': 80 + Math.floor(Math.random()*30),
                  'Deadlift': 140 + Math.floor(Math.random()*50),
                  'Clean': 70 + Math.floor(Math.random()*20)
              }
          };
      }).filter(a => a.name.toLowerCase().includes(reportSearch.toLowerCase()))
        .sort((a,b) => reportSort === 'hours' ? b.totalHours - a.totalHours : b.totalChanges - a.totalChanges);

  }, [events, reportSearch, reportSort]);

  const renderWorkouts = () => (
      <div className="flex flex-col h-full animate-in fade-in slide-in-from-right-4 duration-300">
          <div className="p-4 bg-background/95 backdrop-blur sticky top-0 z-10 space-y-3 border-b border-white/5">
              <div className="flex justify-between items-center">
                <h2 className="text-xl font-bold">Tutti gli Allenamenti</h2>
                {activeFiltersCount > 0 && (
                    <button onClick={resetFilters} className="text-[10px] uppercase font-bold text-red-400 flex items-center gap-1 hover:underline">
                        <RotateCcw className="w-3 h-3" /> Reset
                    </button>
                )}
              </div>

              <div className="flex gap-2">
                  <div className="relative flex-1">
                      <Search className="absolute left-3 top-2.5 w-4 h-4 text-gray-500" />
                      <input 
                          type="text" 
                          placeholder="Cerca per titolo, team..." 
                          value={workoutSearch}
                          onChange={(e) => setWorkoutSearch(e.target.value)}
                          className="w-full bg-surface border border-white/10 rounded-xl py-2 pl-9 pr-4 text-sm text-white focus:ring-1 focus:ring-secondary placeholder:text-gray-500"
                      />
                  </div>
                  <button onClick={() => setShowFilters(!showFilters)} className={`flex items-center gap-2 px-3 rounded-xl border transition-all ${showFilters || activeFiltersCount > 0 ? 'bg-secondary text-white border-secondary' : 'bg-surface border-white/10 text-gray-400'}`}>
                      {showFilters ? <X className="w-4 h-4" /> : <SlidersHorizontal className="w-4 h-4" />}
                      {activeFiltersCount > 0 && <span className="bg-white text-secondary text-[10px] font-bold px-1.5 rounded-full">{activeFiltersCount}</span>}
                  </button>
              </div>

              {showFilters && (
                  <div className="bg-card border border-white/10 rounded-xl p-4 space-y-4 animate-in slide-in-from-top-2">
                      <div className="grid grid-cols-2 gap-3">
                          <div className="space-y-1">
                              <label className="text-[10px] uppercase font-bold text-gray-500">Dal</label>
                              <input type="date" value={filterStartDate} onChange={(e) => setFilterStartDate(e.target.value)} className="w-full bg-surface border-white/10 rounded-lg p-2 text-xs text-white" />
                          </div>
                          <div className="space-y-1">
                              <label className="text-[10px] uppercase font-bold text-gray-500">Al</label>
                              <input type="date" value={filterEndDate} onChange={(e) => setFilterEndDate(e.target.value)} className="w-full bg-surface border-white/10 rounded-lg p-2 text-xs text-white" />
                          </div>
                      </div>
                      <div className="space-y-1">
                          <label className="text-[10px] uppercase font-bold text-gray-500">Luogo</label>
                          <div className="relative">
                              <MapPin className="absolute left-2.5 top-2.5 w-3.5 h-3.5 text-gray-500" />
                              <input type="text" placeholder="Cerca località..." value={filterLocation} onChange={(e) => setFilterLocation(e.target.value)} className="w-full bg-surface border-white/10 rounded-lg p-2 pl-8 text-xs text-white" />
                          </div>
                      </div>
                      <div className="space-y-2">
                          <label className="text-[10px] uppercase font-bold text-gray-500">Specialità</label>
                          <div className="flex flex-wrap gap-2">
                              {['SL', 'GS', 'SG', 'DH', 'Gym'].map(spec => (
                                  <button key={spec} onClick={() => setFilterSpecialty(filterSpecialty === spec ? '' : spec)} className={`px-3 py-1.5 rounded-lg text-xs font-bold border transition-all ${filterSpecialty === spec ? 'bg-secondary border-secondary text-white' : 'bg-surface border-white/10 text-gray-500 hover:text-white'}`}>
                                      {spec}
                                  </button>
                              ))}
                          </div>
                      </div>
                  </div>
              )}
          </div>

          <div className="flex-1 overflow-y-auto p-4 space-y-3">
              {filteredWorkouts.length > 0 ? (
                  filteredWorkouts.map(event => {
                      const team = teams.find(t => t.id === event.teamId);
                      const isPast = new Date(event.date) < new Date();
                      return (
                          <div key={event.id} onClick={() => onEventSelect(event.id)} className={`bg-card border border-white/5 p-4 rounded-xl relative overflow-hidden cursor-pointer hover:border-white/20 active:scale-[0.99] transition ${isPast ? 'opacity-75' : ''}`}>
                              <div className={`absolute left-0 top-0 bottom-0 w-1 ${event.type === 'match' ? 'bg-orange-500' : event.sportCategory === 'dryland' ? 'bg-amber-500' : 'bg-secondary'}`}></div>
                              <div className="pl-3">
                                  <div className="flex justify-between items-start mb-1">
                                      <div className="flex items-center gap-2">
                                          <span className="text-xs text-white font-bold font-mono bg-white/10 px-1.5 py-0.5 rounded">{event.date}</span>
                                          {event.sportCategory === 'dryland' ? (
                                              <span className="text-[9px] font-bold uppercase bg-amber-500/20 text-amber-500 px-1.5 py-0.5 rounded flex items-center gap-1">
                                                  <Dumbbell className="w-2 h-2" /> {event.drylandSpecialty || 'Atletico'}
                                              </span>
                                          ) : (
                                              <>
                                                  <span className="text-[9px] font-bold uppercase bg-sky-500/20 text-sky-400 px-1.5 py-0.5 rounded flex items-center gap-1">
                                                      <Snowflake className="w-2 h-2" /> Sci
                                                  </span>
                                                  {event.technicalDetails?.specialties?.map(s => (
                                                      <span key={s} className="text-[9px] font-bold uppercase bg-secondary/20 text-secondary px-1.5 py-0.5 rounded">{s}</span>
                                                  ))}
                                              </>
                                          )}
                                      </div>
                                      {isPast && <span className="text-[9px] font-bold uppercase text-gray-500">Completato</span>}
                                  </div>
                                  <h3 className="font-bold text-base mt-1">{event.title}</h3>
                                  <div className="flex justify-between items-end mt-2">
                                      <div>
                                          <p className="text-xs text-gray-400 flex items-center gap-1"><Users className="w-3 h-3" /> {team?.name}</p>
                                          {event.location && <p className="text-xs text-gray-500 flex items-center gap-1 mt-0.5"><MapPin className="w-3 h-3" /> {event.location}</p>}
                                      </div>
                                      <p className="text-xs text-white font-bold bg-white/5 px-2 py-1 rounded">{event.startTime} - {event.endTime}</p>
                                  </div>
                              </div>
                          </div>
                      );
                  })
              ) : (
                  <div className="flex flex-col items-center justify-center py-20 text-gray-500 opacity-60">
                      <Search className="w-12 h-12 mb-4 text-gray-600" />
                      <p className="text-sm font-bold">Nessun allenamento trovato.</p>
                      <p className="text-xs">Prova a modificare i filtri di ricerca.</p>
                      {(workoutSearch || activeFiltersCount > 0) && (
                          <button onClick={resetFilters} className="mt-4 text-secondary text-xs font-bold uppercase hover:underline">Resetta filtri</button>
                      )}
                  </div>
              )}
          </div>
      </div>
  );

  return (
    <div className="min-h-screen bg-background relative flex flex-col pb-24">
      {notificationSent && (
          <div className="fixed top-4 left-1/2 -translate-x-1/2 z-[70] bg-green-500 text-white px-6 py-3 rounded-full shadow-2xl flex items-center gap-2 animate-in slide-in-from-top-4 fade-in">
              <CheckCircle className="w-5 h-5" />
              <span className="font-bold text-sm">{notificationSent}</span>
          </div>
      )}

      {/* --- HEADER (ONLY VISIBLE ON HOME) --- */}
      {!selectedAthleteId && activeTab === 'home' && (
        <header className="bg-surface/90 backdrop-blur-xl border-b border-white/5 sticky top-0 z-20 px-4 py-4">
            <div className="flex justify-between items-center">
                <div>
                    <p className="text-xs font-bold text-gray-400 uppercase tracking-widest">Welcome Coach</p>
                    <h1 className="text-2xl font-black">{userProfile.firstName} {userProfile.lastName}</h1>
                </div>
                <div className="flex gap-2">
                    <button 
                        onClick={() => setActiveTab('profile')}
                        className="w-10 h-10 rounded-full bg-white/5 flex items-center justify-center hover:bg-white/10 transition"
                    >
                        <User className="w-5 h-5 text-white" />
                    </button>
                </div>
            </div>
        </header>
      )}

      {/* --- MAIN CONTENT AREA --- */}
      <main className="flex-1 overflow-y-auto">
          {activeTab === 'home' && (
              <CalendarView 
                events={events} 
                teams={teams} 
                onEventSelect={onEventSelect}
                onCreateEvent={onCreateEvent}
                selectedDate={selectedDate}
                onDateChange={setSelectedDate}
              />
          )}
          
          {activeTab === 'reports' && (
              <CoachReports 
                athleteStats={athleteStats} 
                teams={teams} 
                globalStats={globalStats}
                reportSearch={reportSearch} setReportSearch={setReportSearch}
                reportSort={reportSort} setReportSort={setReportSort}
                selectedAthleteId={selectedAthleteId} setSelectedAthleteId={setSelectedAthleteId}
                reportViewMode={reportViewMode} setReportViewMode={setReportViewMode}
                selectedSessionId={selectedSessionId} setSelectedSessionId={setSelectedSessionId}
                selectedChartType={selectedChartType} setSelectedChartType={setSelectedChartType}
              />
          )}

          {activeTab === 'workouts' && renderWorkouts()}
          
          {activeTab === 'profile' && (
              <Profile 
                setView={(view) => { if(view === 'home') setActiveTab('home'); }} 
                userProfile={userProfile} 
                onSave={onSaveProfile} 
                onLogout={onLogout}
                showBackArrow={false} 
              />
          )}
      </main>

      {/* --- FAB (Only on Home/Calendar) --- */}
      {activeTab === 'home' && (
        <div className="fixed bottom-24 right-6 z-40">
            <button 
                onClick={() => onCreateEvent(selectedDateStr)}
                className="w-14 h-14 bg-white text-black rounded-full shadow-2xl flex items-center justify-center hover:scale-105 transition-transform active:scale-95"
            >
                <Plus className="w-6 h-6" />
            </button>
        </div>
      )}

      {/* --- COACH BOTTOM NAVIGATION --- */}
      <div className="fixed bottom-0 left-0 right-0 bg-surface/95 backdrop-blur border-t border-white/5 pb-safe z-50">
          <div className="flex justify-around items-center h-20">
            <button onClick={() => { setActiveTab('home'); setSelectedAthleteId(null); setReportViewMode('overview'); }} className="flex flex-col items-center gap-1 group">
              <div className={`p-1 rounded-xl transition-colors ${activeTab === 'home' ? 'text-secondary' : 'text-gray-500 group-hover:text-gray-300'}`}>
                  <HomeIcon className="w-6 h-6" />
              </div>
              <span className={`text-[10px] font-medium ${activeTab === 'home' ? 'text-secondary' : 'text-gray-500'}`}>Home</span>
            </button>
            
            <button onClick={() => { setActiveTab('reports'); setSelectedAthleteId(null); setReportViewMode('overview'); }} className="flex flex-col items-center gap-1 group">
              <div className={`p-1 rounded-xl transition-colors ${activeTab === 'reports' ? 'text-secondary' : 'text-gray-500 group-hover:text-gray-300'}`}>
                  <ClipboardList className="w-6 h-6" />
              </div>
              <span className={`text-[10px] font-medium ${activeTab === 'reports' ? 'text-secondary' : 'text-gray-500'}`}>Report</span>
            </button>
            
            <button onClick={() => { setActiveTab('workouts'); setSelectedAthleteId(null); setReportViewMode('overview'); }} className="flex flex-col items-center gap-1 group">
              <div className={`p-1 rounded-xl transition-colors ${activeTab === 'workouts' ? 'text-secondary' : 'text-gray-500 group-hover:text-gray-300'}`}>
                  <LayoutList className="w-6 h-6" />
              </div>
              <span className={`text-[10px] font-medium ${activeTab === 'workouts' ? 'text-secondary' : 'text-gray-500'}`}>Allenamenti</span>
            </button>

            {/* Profile Tab */}
            <button onClick={() => { setActiveTab('profile'); setSelectedAthleteId(null); setReportViewMode('overview'); }} className="flex flex-col items-center gap-1 group">
              <div className={`p-1 rounded-xl transition-colors ${activeTab === 'profile' ? 'text-secondary' : 'text-gray-500 group-hover:text-gray-300'}`}>
                  <User className="w-6 h-6" />
              </div>
              <span className={`text-[10px] font-medium ${activeTab === 'profile' ? 'text-secondary' : 'text-gray-500'}`}>Profilo</span>
            </button>
          </div>
        </div>

    </div>
  );
};

// Extracted Reports Component to fix Hook Violation
const CoachReports: React.FC<{
    athleteStats: AthleteStats[];
    teams: Team[];
    globalStats: any;
    reportSearch: string;
    setReportSearch: (val: string) => void;
    reportSort: SortMode;
    setReportSort: (val: SortMode) => void;
    selectedAthleteId: string | null;
    setSelectedAthleteId: (id: string | null) => void;
    reportViewMode: ReportViewMode;
    setReportViewMode: (mode: ReportViewMode) => void;
    selectedSessionId: string | null;
    setSelectedSessionId: (id: string | null) => void;
    selectedChartType: ChartType;
    setSelectedChartType: (type: ChartType) => void;
}> = ({ 
    athleteStats, teams, globalStats, 
    reportSearch, setReportSearch, 
    reportSort, setReportSort, 
    selectedAthleteId, setSelectedAthleteId,
    reportViewMode, setReportViewMode,
    selectedSessionId, setSelectedSessionId,
    selectedChartType, setSelectedChartType
}) => {

    if (selectedAthleteId) {
        const athlete = athleteStats.find(a => a.id === selectedAthleteId);
        if (!athlete) return null;

        if (reportViewMode === 'session_detail' && selectedSessionId) {
            const session = athlete.recentSessions.find(s => s.id === selectedSessionId);
            if (session) return <SessionDetailView session={session} onBack={() => setReportViewMode('overview')} />;
        }

        if (reportViewMode === 'chart_detail') {
            const data = selectedChartType === 'weight' ? athlete.weightTrend : athlete.heightTrend;
            return <ChartDetailView type={selectedChartType} data={data} onBack={() => setReportViewMode('overview')} />;
        }

        return (
            <div className="h-full flex flex-col animate-in slide-in-from-right-4 duration-300 bg-background pb-20">
                <div className="sticky top-0 bg-background/95 backdrop-blur z-20 border-b border-white/5 p-4 flex items-center gap-4">
                    <button onClick={() => setSelectedAthleteId(null)} className="w-10 h-10 rounded-full bg-white/5 flex items-center justify-center hover:bg-white/10">
                        <ArrowLeft className="w-5 h-5" />
                    </button>
                    <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-full bg-secondary/10 flex items-center justify-center text-secondary font-bold text-lg">
                            {athlete.name.charAt(0)}
                        </div>
                        <div>
                            <h2 className="font-bold text-lg leading-tight">{athlete.name}</h2>
                            <p className="text-xs text-gray-400">{teams.find(t => t.id === athlete.teamId)?.name}</p>
                        </div>
                    </div>
                </div>

                <div className="flex-1 overflow-y-auto p-4 space-y-6">
                    <div className="grid grid-cols-2 gap-2">
                        <div className="bg-card p-3 rounded-xl border border-white/5 text-center flex flex-col justify-center">
                            <div className="flex items-center justify-center gap-1 mb-1 text-sky-400">
                                <Snowflake className="w-3.5 h-3.5" />
                                <span className="text-[10px] uppercase font-bold text-gray-500">Presenza Sci</span>
                            </div>
                            <p className={`text-xl font-black ${athlete.skiAttendancePct > 80 ? 'text-green-500' : athlete.skiAttendancePct > 50 ? 'text-yellow-500' : 'text-red-500'}`}>
                                {athlete.skiAttendancePct}%
                            </p>
                            <span className="text-[10px] text-gray-500 font-medium">({athlete.skiAttendedCount}/{athlete.skiEventsCount})</span>
                        </div>
                        <div className="bg-card p-3 rounded-xl border border-white/5 text-center flex flex-col justify-center">
                            <div className="flex items-center justify-center gap-1 mb-1 text-amber-500">
                                <Dumbbell className="w-3.5 h-3.5" />
                                <span className="text-[10px] uppercase font-bold text-gray-500">Presenza Atletico</span>
                            </div>
                            <p className={`text-xl font-black ${athlete.drylandAttendancePct > 80 ? 'text-green-500' : athlete.drylandAttendancePct > 50 ? 'text-yellow-500' : 'text-red-500'}`}>
                                {athlete.drylandAttendancePct}%
                            </p>
                            <span className="text-[10px] text-gray-500 font-medium">({athlete.drylandAttendedCount}/{athlete.drylandEventsCount})</span>
                        </div>
                        <div className="bg-card p-3 rounded-xl border border-white/5 text-center">
                            <p className="text-[10px] text-gray-500 uppercase font-bold mb-1">Extra Sci</p>
                            <p className="text-xl font-black text-orange-500">{athlete.nonSkiHours}h</p>
                            <span className="text-[10px] text-gray-500 font-medium">Ore Totali</span>
                        </div>
                        <div className="bg-card p-3 rounded-xl border border-white/5 text-center">
                            <p className="text-[10px] text-gray-500 uppercase font-bold mb-1">Tot. Cambi</p>
                            <p className="text-xl font-black text-secondary">{athlete.totalChanges}</p>
                            <span className="text-[10px] text-gray-500 font-medium">Numero Giri</span>
                        </div>
                    </div>

                    <div className="bg-card p-4 rounded-2xl border border-white/5">
                        <div className="flex items-center gap-2 mb-4">
                            <Zap className="w-4 h-4 text-secondary" />
                            <h3 className="font-bold text-sm">Volume per Specialità (Cambi)</h3>
                        </div>
                        <div className="space-y-3">
                            {Object.entries(athlete.changesBySpec).map(([spec, count]) => {
                                if (count === 0) return null;
                                const max = Math.max(...(Object.values(athlete.changesBySpec) as number[])) || 1;
                                const width = ((count as number) / max) * 100;
                                return (
                                    <div key={spec} className="flex items-center gap-3 text-xs">
                                        <div className="w-8 font-bold">{spec}</div>
                                        <div className="flex-1 h-2 bg-white/5 rounded-full overflow-hidden">
                                            <div className="h-full bg-secondary transition-all" style={{width: `${width}%`}}></div>
                                        </div>
                                        <div className="w-10 text-right font-mono text-gray-400">{count}</div>
                                    </div>
                                )
                            })}
                        </div>
                    </div>

                    <div className="grid grid-cols-2 gap-4">
                        <div onClick={() => { setSelectedChartType('weight'); setReportViewMode('chart_detail'); }} className="bg-card p-4 rounded-2xl border border-white/5 h-40 flex flex-col cursor-pointer hover:border-secondary/50 transition relative group">
                            <div className="flex items-center gap-2 mb-2 text-xs font-bold text-gray-400">
                                <Scale className="w-3 h-3" /> Peso
                            </div>
                            <div className="flex-1 -mx-2 pointer-events-none">
                                <WeightChart data={athlete.weightTrend.map(d => ({...d, bodyFat: 15}))} />
                            </div>
                            <div className="absolute top-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity">
                                <Search className="w-4 h-4 text-white" />
                            </div>
                        </div>
                        <div onClick={() => { setSelectedChartType('height'); setReportViewMode('chart_detail'); }} className="bg-card p-4 rounded-2xl border border-white/5 h-40 flex flex-col cursor-pointer hover:border-secondary/50 transition relative group">
                            <div className="flex items-center gap-2 mb-2 text-xs font-bold text-gray-400">
                                <Ruler className="w-3 h-3" /> Altezza
                            </div>
                            <div className="flex-1 -mx-2 pointer-events-none">
                                <HeightChart data={athlete.heightTrend} />
                            </div>
                            <div className="absolute top-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity">
                                <Search className="w-4 h-4 text-white" />
                            </div>
                        </div>
                    </div>

                    <div className="space-y-3">
                        <h3 className="font-bold text-sm px-1 flex items-center gap-2"><TrendingUp className="w-4 h-4 text-green-500" /> Profilo Salto</h3>
                        <div className="grid grid-cols-3 gap-2">
                            {Object.entries(athlete.jumpStats).map(([type, val]) => (
                                <div key={type} className="bg-card border border-white/5 p-3 rounded-xl text-center">
                                    <p className="text-[10px] uppercase font-bold text-gray-500 mb-1">{type.replace('_', ' ')}</p>
                                    <p className="text-lg font-black text-white">{val} <span className="text-xs font-normal text-gray-500">cm</span></p>
                                </div>
                            ))}
                        </div>
                    </div>

                    <div className="space-y-3">
                        <h3 className="font-bold text-sm px-1 flex items-center gap-2"><Dumbbell className="w-4 h-4 text-orange-500" /> Massimali (1RM)</h3>
                        <div className="grid grid-cols-2 gap-2">
                            {Object.entries(athlete.prStats).map(([lift, val]) => (
                                <div key={lift} className="bg-card border border-white/5 p-3 rounded-xl flex justify-between items-center">
                                    <span className="text-xs font-bold text-gray-400">{lift}</span>
                                    <span className="font-black text-white">{val} <span className="text-[10px] text-gray-600">kg</span></span>
                                </div>
                            ))}
                        </div>
                    </div>

                    <div>
                        <h3 className="font-bold text-sm mb-3 px-1">Storico Attività</h3>
                        <div className="space-y-3">
                            {athlete.recentSessions.map(session => (
                                <div key={session.id} onClick={() => { setSelectedSessionId(session.id); setReportViewMode('session_detail'); }} className="bg-card border border-white/5 p-3 rounded-xl flex gap-3 cursor-pointer hover:bg-white/5 active:scale-[0.99] transition">
                                    <div className={`w-10 h-10 rounded-lg flex items-center justify-center shrink-0 ${session.sportId === 'alpine_skiing' ? 'bg-secondary/10 text-secondary' : 'bg-orange-500/10 text-orange-500'}`}>
                                        {session.sportId === 'alpine_skiing' ? <Snowflake className="w-5 h-5" /> : <Dumbbell className="w-5 h-5" />}
                                    </div>
                                    <div className="flex-1">
                                        <div className="flex justify-between items-center">
                                            <span className="font-bold text-sm capitalize">{session.sportId.replace('_', ' ')}</span>
                                            <ChevronRight className="w-4 h-4 text-gray-600" />
                                        </div>
                                        <div className="flex items-center gap-3 mt-1 text-xs text-gray-400">
                                            <span>{session.date}</span>
                                            <span>•</span>
                                            <span className="flex items-center gap-1"><Clock className="w-3 h-3" /> {session.duration}</span>
                                            {session.sportId === 'running_road' && <span>• {session.details?.running?.distance}km</span>}
                                        </div>
                                    </div>
                                </div>
                            ))}
                        </div>
                    </div>
                </div>
            </div>
        );
    }

    return (
        <div className="flex flex-col h-full animate-in fade-in slide-in-from-right-4 duration-300">
            <div className="p-4 space-y-4">
                <h2 className="text-xl font-bold">Report Atleti</h2>
                
                <div className="bg-gradient-to-br from-card to-surface border border-white/5 p-4 rounded-2xl shadow-lg">
                    <div className="flex justify-between items-start mb-4">
                        <div>
                            <p className="text-xs text-gray-400 uppercase font-bold">Giornate Totali</p>
                            <p className="text-3xl font-black text-white">{globalStats.totalDays}</p>
                        </div>
                        <div className="p-2 bg-secondary/10 rounded-lg">
                            <CalendarDays className="w-5 h-5 text-secondary" />
                        </div>
                    </div>
                    <div className="flex flex-wrap gap-2">
                        {Object.entries(globalStats.breakdown).map(([spec, count]) => (
                            <div key={spec} className="px-2 py-1 bg-white/5 rounded text-xs border border-white/10 flex items-center gap-1.5">
                                <span className="font-bold text-gray-300">{spec}</span>
                                <span className="font-mono text-secondary">{count}</span>
                            </div>
                        ))}
                    </div>
                </div>

                <div className="flex gap-2">
                    <div className="relative flex-1">
                        <Search className="absolute left-3 top-2.5 w-4 h-4 text-gray-500" />
                        <input type="text" placeholder="Cerca atleta..." value={reportSearch} onChange={(e) => setReportSearch(e.target.value)} className="w-full bg-card border border-white/10 rounded-xl py-2 pl-9 pr-4 text-sm text-white focus:ring-1 focus:ring-secondary" />
                    </div>
                    <button onClick={() => setReportSort(prev => prev === 'hours' ? 'changes' : 'hours')} className="px-3 bg-card border border-white/10 rounded-xl flex items-center gap-2 text-xs font-bold text-gray-300 hover:bg-white/5">
                        {reportSort === 'hours' ? <Clock className="w-3 h-3" /> : <Activity className="w-3 h-3" />}
                        {reportSort === 'hours' ? 'Ore' : 'Cambi'}
                    </button>
                </div>
            </div>

            <div className="flex-1 overflow-y-auto px-4 pb-24 space-y-6">
                {teams.map(team => {
                    const teamAthletes = athleteStats.filter(a => a.teamId === team.id);
                    if (teamAthletes.length === 0) return null;

                    return (
                        <div key={team.id} className="space-y-2">
                            <div className="flex items-center gap-2 px-1">
                                <Users className="w-3 h-3 text-gray-500" />
                                <h3 className="text-xs font-bold uppercase text-gray-500">{team.name}</h3>
                            </div>
                            
                            {teamAthletes.map(athlete => (
                                <div key={athlete.id} onClick={() => setSelectedAthleteId(athlete.id)} className="bg-card border border-white/5 p-3 rounded-xl flex items-center gap-3 cursor-pointer hover:border-secondary/50 active:scale-[0.99] transition">
                                    <div className="w-10 h-10 bg-gradient-to-br from-gray-700 to-gray-800 rounded-full flex items-center justify-center font-bold text-white border border-white/10">
                                        {athlete.name.charAt(0)}
                                    </div>
                                    <div className="flex-1 min-w-0">
                                        <div className="flex justify-between items-center mb-1">
                                            <h4 className="font-bold text-sm truncate pr-2">{athlete.name}</h4>
                                            {reportSort === 'hours' ? (
                                                <span className="text-sm font-black text-white">{athlete.totalHours}h</span>
                                            ) : (
                                                <span className="text-sm font-black text-secondary">{athlete.totalChanges}</span>
                                            )}
                                        </div>
                                         <div className="flex items-center flex-wrap gap-x-2 gap-y-1 text-xs text-gray-500">
                                             <span className="flex items-center gap-1 bg-sky-500/10 text-sky-400 px-1.5 py-0.5 rounded">
                                                 <Snowflake className="w-2.5 h-2.5" /> Sci: {athlete.skiAttendancePct}%
                                             </span>
                                             <span className="flex items-center gap-1 bg-amber-500/10 text-amber-500 px-1.5 py-0.5 rounded">
                                                 <Dumbbell className="w-2.5 h-2.5" /> Atletico: {athlete.drylandAttendancePct}%
                                             </span>
                                         </div>
                                    </div>
                                    <ChevronRight className="w-4 h-4 text-gray-600" />
                                </div>
                            ))}
                        </div>
                    );
                })}
            </div>
        </div>
    );
}

export default CoachDashboard;
