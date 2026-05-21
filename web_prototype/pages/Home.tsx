
import React, { useState, useMemo } from 'react';
import { Bell, TrendingDown, TrendingUp, Plus, Dumbbell, Activity, Monitor, Scale, Minus, Ruler } from 'lucide-react';
import { ViewState, UserProfile, TrainingSession, BodyMetricLog } from '../types';
import { WeightChart, HeightChart } from '../components/Charts';
import { translations } from '../i18n';
import { sportsData } from '../data/sports';

interface Props {
  setView: (view: ViewState) => void;
  userProfile: UserProfile;
  sessions?: TrainingSession[];
  bodyLogs?: BodyMetricLog[];
  onSessionClick?: (sessionId: string) => void;
  onBodyMetricsClick?: (metric: 'weight' | 'height') => void;
}

const Home: React.FC<Props> = ({ setView, userProfile, sessions = [], bodyLogs = [], onSessionClick, onBodyMetricsClick }) => {
  const [isFabOpen, setIsFabOpen] = useState(false);
  const t = translations[userProfile.language];

  // Date formatting options
  const dateOptions: Intl.DateTimeFormatOptions = { weekday: 'long', month: 'short', day: 'numeric' };
  const currentDate = new Date().toLocaleDateString(userProfile.language === 'it' ? 'it-IT' : 'en-US', dateOptions);

  // --- AGE CALCULATION ---
  const isUnder18 = useMemo(() => {
    const birthDate = new Date(userProfile.birthDate);
    const today = new Date();
    let age = today.getFullYear() - birthDate.getFullYear();
    const m = today.getMonth() - birthDate.getMonth();
    if (m < 0 || (m === 0 && today.getDate() < birthDate.getDate())) {
        age--;
    }
    return age < 18;
  }, [userProfile.birthDate]);

  // --- CHART DATA GENERATION from Logs ---
  const getChartData = (type: 'weight' | 'height') => {
     return bodyLogs
        .filter(log => log.type === type)
        .sort((a,b) => new Date(a.date).getTime() - new Date(b.date).getTime())
        .slice(-6) // Last 6 entries for home view
        .map(log => {
             const d = new Date(log.date);
             const dateStr = d.toLocaleDateString(userProfile.language === 'it' ? 'it-IT' : 'en-US', { month: 'short', day: 'numeric' });
             
             if (type === 'weight') {
                 // Convert stored kg to user preference for display in chart
                 const val = userProfile.unitSystem === 'metric' ? log.value : log.value * 2.20462;
                 const mockBodyFat = 15 + Math.random() * 2;
                 return { 
                    date: dateStr, 
                    weight: parseFloat(val.toFixed(1)), 
                    bodyFat: parseFloat(mockBodyFat.toFixed(1)) 
                 };
             } else {
                 const val = userProfile.unitSystem === 'metric' ? log.value : log.value / 30.48;
                 return { date: dateStr, height: parseFloat(val.toFixed(2)) };
             }
        });
  };

  const weightHistory = useMemo(() => getChartData('weight') as { date: string; weight: number; bodyFat: number }[], [bodyLogs, userProfile.unitSystem]);
  const heightHistory = useMemo(() => getChartData('height') as { date: string; height: number }[], [bodyLogs, userProfile.unitSystem]);

  // --- DYNAMIC DELTA CALCULATION ---
  const lastWeight = weightHistory.length > 0 ? weightHistory[weightHistory.length - 1].weight : 0;
  const prevWeight = weightHistory.length > 1 ? weightHistory[weightHistory.length - 2].weight : lastWeight;
  
  // Calculate difference
  const rawDiff = lastWeight - prevWeight;
  const isWeightDown = rawDiff < 0;
  const isWeightSame = rawDiff === 0;
  
  // Formatting for display
  const displayWeight = userProfile.unitSystem === 'metric' 
    ? userProfile.weight 
    : (userProfile.weight * 2.20462).toFixed(1);

  const displayHeight = userProfile.unitSystem === 'metric' 
    ? Math.round(userProfile.height)
    : (userProfile.height / 30.48).toFixed(2);
  
  const weightUnit = userProfile.unitSystem === 'metric' ? 'kg' : 'lbs';
  const heightUnit = userProfile.unitSystem === 'metric' ? 'cm' : 'ft';
  
  // Convert diff to correct unit for display
  const displayDiffVal = Math.abs(rawDiff).toFixed(1);
  const diffString = `${displayDiffVal} ${weightUnit}`;

  // --- ALPINE SKIING STATS ---
  const alpineStats = useMemo(() => {
    let totalGatedVolume = 0;
    const bySpecialty: Record<string, number> = {};

    sessions.forEach(session => {
        if (session.sportId === 'alpine_skiing' && session.details?.gatedSkiing) {
            const changes = parseInt(session.details.gatedSkiing.changes || '0', 10);
            const laps = parseInt(session.details.gatedSkiing.laps || '0', 10);
            if (!isNaN(changes) && !isNaN(laps)) {
                const sessionVol = changes * laps;
                if (sessionVol > 0) {
                    totalGatedVolume += sessionVol;
                    const specName = (session.details.specialties && session.details.specialties.length > 0)
                        ? session.details.specialties[0]
                        : 'Mixed'; 
                    bySpecialty[specName] = (bySpecialty[specName] || 0) + sessionVol;
                }
            }
        }
    });

    return { total: totalGatedVolume, breakdown: bySpecialty };
  }, [sessions]);

  // --- GYM STATS ---
  const gymStats = useMemo(() => {
    let totalMinutes = 0;
    sessions.forEach(session => {
        if (session.sportId === 'alpine_skiing') return;
        const hMatch = session.duration.match(/(\d+)h/);
        const mMatch = session.duration.match(/(\d+)m/);
        const hours = hMatch ? parseInt(hMatch[1], 10) : 0;
        const minutes = mMatch ? parseInt(mMatch[1], 10) : 0;
        totalMinutes += (hours * 60) + minutes;
    });
    const displayHours = Math.floor(totalMinutes / 60);
    const displayMinutes = totalMinutes % 60;
    return { hours: displayHours, minutes: displayMinutes };
  }, [sessions]);

  const handleFabAction = (action: () => void) => {
    action();
    setIsFabOpen(false);
  };

  const getSportData = (id: string) => sportsData.find(s => s.id === id) || sportsData[0];

  const handleWeightClick = () => {
      if (onBodyMetricsClick) onBodyMetricsClick('weight');
      else setView('body-metrics');
  };

  const handleHeightClick = () => {
      if (onBodyMetricsClick) onBodyMetricsClick('height');
      else setView('body-metrics');
  };

  return (
    <div className="pb-24 pt-4 px-4 space-y-6 relative min-h-screen">
      {/* Background Overlay when FAB is open */}
      {isFabOpen && (
        <div 
            className="fixed inset-0 bg-black/60 backdrop-blur-[2px] z-30 transition-opacity" 
            onClick={() => setIsFabOpen(false)}
        ></div>
      )}

      {/* Header */}
      <header className="flex justify-between items-center">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-full bg-gray-700 bg-cover bg-center border-2 border-secondary/20" 
               style={{backgroundImage: `url("${userProfile.avatarUrl}")`}}>
          </div>
          <div>
            <p className="text-xs text-gray-400 font-medium uppercase tracking-wider">{t.today}</p>
            <h1 className="text-lg font-bold capitalize">{currentDate}</h1>
          </div>
        </div>
        {/* Notification Icon Removed as requested */}
      </header>

      {/* Season Performance */}
      <section className="space-y-4">
        <h2 className="text-lg font-bold">{t.seasonPerformance}</h2>
        <div className="grid grid-cols-2 gap-3">
          <div className="bg-card rounded-2xl p-4 border border-white/5">
            <div className="flex items-center gap-2 mb-2">
              <Activity className="w-5 h-5 text-secondary" />
              <span className="text-[10px] font-bold text-gray-400 uppercase">{t.dirChanges} <span className="text-[9px] opacity-60">(Pali)</span></span>
            </div>
            <p className="text-2xl font-bold mb-3">{alpineStats.total.toLocaleString()}</p>
            <div className="space-y-2">
              {Object.entries(alpineStats.breakdown).length > 0 ? (
                  Object.entries(alpineStats.breakdown).map(([spec, val]) => (
                    <div key={spec} className="flex justify-between items-center text-xs">
                        <div className="flex items-center gap-2">
                            <div className={`w-1.5 h-1.5 rounded-full ${spec === 'SL' ? 'bg-secondary' : spec === 'GS' ? 'bg-sky-400' : 'bg-gray-500'}`}></div>
                            <span className="text-gray-400">{spec}</span>
                        </div>
                        <span className="font-mono">{val.toLocaleString()}</span>
                    </div>
                  ))
              ) : (
                  <p className="text-[10px] text-gray-500 italic">No gated activity yet.</p>
              )}
            </div>
          </div>

          <div className="bg-card rounded-2xl p-4 border border-white/5 flex flex-col justify-between">
            <div>
              <div className="flex items-center gap-2 mb-2">
                <Dumbbell className="w-5 h-5 text-orange-500" />
                <span className="text-[10px] font-bold text-gray-400 uppercase">{t.hours}</span>
              </div>
              <p className="text-2xl font-bold">
                {gymStats.hours}<span className="text-sm font-normal text-gray-400 ml-1">h</span> {gymStats.minutes}<span className="text-sm font-normal text-gray-400 ml-1">m</span>
              </p>
            </div>
            <div>
              <p className="text-[10px] text-gray-400">{t.totalVolume}</p>
            </div>
          </div>
        </div>
      </section>

      {/* Recent Activities */}
      <section className="space-y-4">
        <h2 className="text-lg font-bold">{t.recentActivities}</h2>
        
        {sessions.length > 0 ? (
          sessions.slice(0, 3).map((session) => {
            const sport = getSportData(session.sportId);
            const SportIcon = sport.icon;
            
            return (
              <div 
                key={session.id} 
                onClick={() => onSessionClick && onSessionClick(session.id)}
                className="bg-card rounded-2xl p-4 border border-white/5 flex gap-4 animate-in slide-in-from-right-4 fade-in cursor-pointer active:scale-[0.98] transition hover:border-white/10"
              >
                <div className={`w-12 h-12 rounded-xl flex items-center justify-center shrink-0 ${session.sportId === 'alpine_skiing' ? 'bg-secondary/10' : 'bg-orange-500/10'}`}>
                   <SportIcon className={`w-6 h-6 ${session.sportId === 'alpine_skiing' ? 'text-secondary' : 'text-orange-500'}`} />
                </div>
                <div className="flex-1">
                  <div className="flex justify-between">
                     <h3 className="font-semibold text-base">{sport.name}</h3>
                     <span className="text-xs text-gray-500">{session.date === new Date().toISOString().split('T')[0] ? t.today : session.date}</span>
                  </div>
                  {session.details?.specialties ? (
                     <p className="text-sm text-gray-400">{session.details.specialties.join(', ')}</p>
                  ) : (
                     <p className="text-sm text-gray-400">Training Session</p>
                  )}
                  
                  <div className="flex items-center gap-3 mt-2 text-xs text-gray-400 font-mono">
                    <span>{session.duration}</span>
                    <span className="w-1 h-1 bg-gray-600 rounded-full"></span>
                    <span>RPE {session.effort}/10</span>
                  </div>
                </div>
              </div>
            );
          })
        ) : (
          <p className="text-gray-500 text-sm italic">No recent activities.</p>
        )}
      </section>

      {/* Body Weight */}
      <section className="bg-card rounded-2xl p-5 border border-white/5 cursor-pointer active:scale-[0.99] transition" onClick={handleWeightClick}>
        <div className="flex justify-between items-end mb-4">
          <div>
            <h3 className="text-base font-bold mb-1">{t.bodyWeightFat}</h3>
            <div className="flex items-baseline gap-2">
              <span className="text-2xl font-bold">{displayWeight}</span>
              <span className="text-sm text-gray-400">{weightUnit}</span>
            </div>
          </div>
          
          {/* Dynamic Trend Indicator */}
          {isWeightSame ? (
             <div className="flex items-center gap-1 text-gray-400 bg-white/5 px-2 py-1 rounded text-xs font-bold">
                <Minus className="w-3 h-3" />
                <span>{t.steady}</span>
             </div>
          ) : (
            <div className={`flex items-center gap-1 px-2 py-1 rounded text-xs font-bold ${isWeightDown ? 'text-emerald-500 bg-emerald-500/10' : 'text-secondary bg-secondary/10'}`}>
                {isWeightDown ? <TrendingDown className="w-3 h-3" /> : <TrendingUp className="w-3 h-3" />}
                <span>{diffString}</span>
            </div>
          )}
        </div>
        
        <div className="h-40 w-full">
           <WeightChart data={weightHistory} />
        </div>
      </section>

      {/* Height Tracking (Only for Under 18) */}
      {isUnder18 && (
        <section className="bg-card rounded-2xl p-5 border border-white/5 cursor-pointer active:scale-[0.99] transition" onClick={handleHeightClick}>
            <div className="flex justify-between items-end mb-4">
                <div>
                    <h3 className="text-base font-bold mb-1">{t.height} Trend</h3>
                    <div className="flex items-baseline gap-2">
                        <span className="text-2xl font-bold">{displayHeight}</span>
                        <span className="text-sm text-gray-400">{heightUnit}</span>
                    </div>
                </div>
                 <div className="flex items-center gap-1 text-emerald-500 bg-emerald-500/10 px-2 py-1 rounded text-xs font-bold">
                    <TrendingUp className="w-3 h-3" />
                    <span>Growing</span>
                 </div>
            </div>
            
            <div className="h-40 w-full">
                <HeightChart data={heightHistory} />
            </div>
        </section>
      )}

      {/* Floating Action Button Group */}
      <div className="fixed bottom-24 right-4 flex flex-col items-end gap-4 z-40">
         {isFabOpen && (
            <div className="flex flex-col items-end gap-3 animate-in slide-in-from-bottom-4 duration-200 fade-in">
                 {/* Add Weight Button */}
                 <button 
                    onClick={() => handleFabAction(handleWeightClick)} 
                    className="bg-white text-black text-sm font-semibold px-4 py-2.5 rounded-lg shadow-lg flex items-center gap-2 transform hover:-translate-x-1 transition"
                 >
                    {t.addWeight} <Scale className="w-4 h-4" />
                 </button>
                 
                 {/* Add Training Button */}
                 <button 
                    onClick={() => handleFabAction(() => setView('add-training'))} 
                    className="bg-white text-black text-sm font-semibold px-4 py-2.5 rounded-lg shadow-lg flex items-center gap-2 transform hover:-translate-x-1 transition"
                 >
                    {t.addTraining} <Dumbbell className="w-4 h-4" />
                 </button>
            </div>
         )}
         
         {/* Main Toggle Button */}
         <button 
            onClick={() => setIsFabOpen(!isFabOpen)} 
            className={`w-14 h-14 bg-secondary rounded-full shadow-lg shadow-secondary/20 flex items-center justify-center hover:scale-105 transition-transform active:scale-95 ${isFabOpen ? 'bg-gray-700' : ''}`}
         >
           <Plus className={`w-8 h-8 text-white transition-transform duration-300 ${isFabOpen ? 'rotate-45' : ''}`} />
         </button>
      </div>
    </div>
  );
};

export default Home;
