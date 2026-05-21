
import React, { useState } from 'react';
import { Share, ChevronRight, Dumbbell, History, Edit2, Trash2, X, Check, ArrowUpRight, ArrowDownRight, Minus, Ruler, Scale } from 'lucide-react';
import { ViewState, UnitSystem, Language, TrainingSession, BodyMetricLog, JumpLog, JumpType } from '../types';
import { translations } from '../i18n';
import { sportsData } from '../data/sports';

interface Props {
  setView: (view: ViewState) => void;
  unitSystem: UnitSystem;
  language: Language;
  birthDate?: string;
  sessions?: TrainingSession[];
  bodyLogs?: BodyMetricLog[];
  jumpLogs?: JumpLog[];
  onSessionClick?: (sessionId: string) => void;
  onUpdateBodyLog?: (id: string, newVal: number) => void;
  onDeleteBodyLog?: (id: string) => void;
  onExerciseClick?: (exerciseId: string) => void;
  onJumpClick?: (jumpType: JumpType) => void;
  onBodyMetricsClick?: (metric: 'weight' | 'height') => void;
}

const Analytics: React.FC<Props> = ({ 
    setView, 
    unitSystem, 
    language, 
    birthDate,
    sessions = [], 
    bodyLogs = [], 
    jumpLogs = [],
    onSessionClick,
    onUpdateBodyLog,
    onDeleteBodyLog,
    onExerciseClick,
    onJumpClick,
    onBodyMetricsClick
}) => {
  const t = translations[language];
  const [editingLog, setEditingLog] = useState<BodyMetricLog | null>(null);
  const [editValue, setEditValue] = useState('');

  // --- AGE CALCULATION ---
  const isUnder18 = (() => {
    if (!birthDate) return true;
    const birth = new Date(birthDate);
    const today = new Date();
    let age = today.getFullYear() - birth.getFullYear();
    const m = today.getMonth() - birth.getMonth();
    if (m < 0 || (m === 0 && today.getDate() < birth.getDate())) {
        age--;
    }
    return age < 18;
  })();

  // Conversion Helpers
  const cmToUnit = (cm: number) => unitSystem === 'metric' ? cm : Math.round(cm / 30.48 * 10) / 10; 
  const jumpVal = (cm: number) => unitSystem === 'metric' ? cm : Math.round(cm * 0.393701); // cm to inches approx
  const jumpUnit = unitSystem === 'metric' ? 'cm' : 'in';

  const kgToUnit = (kg: number) => unitSystem === 'metric' ? kg : Math.round(kg * 2.20462);
  const weightUnit = unitSystem === 'metric' ? 'kg' : 'lbs';
  const heightUnit = unitSystem === 'metric' ? 'cm' : 'ft';

  const getSportData = (id: string) => sportsData.find(s => s.id === id) || sportsData[0];

  // Helper to process logs for display (calculating trend before slicing)
  const getProcessedLogs = (type: 'weight' | 'height') => {
      const logs = bodyLogs
        .filter(l => l.type === type)
        .sort((a,b) => new Date(b.date).getTime() - new Date(a.date).getTime());
      
      // Return top 3, but calculate trend based on the full list relative to the item
      return logs.slice(0, 3).map((log, index) => {
          let trend: 'up' | 'down' | 'equal' | null = null;
          let diff = 0;
          // Look ahead in the full 'logs' array for the previous entry
          if (index < logs.length - 1) {
              const prevVal = logs[index + 1].value;
              diff = log.value - prevVal;
              if (diff > 0) trend = 'up';
              else if (diff < 0) trend = 'down';
              else trend = 'equal';
          }
          return { log, trend, diff };
      });
  };

  const recentWeightLogs = getProcessedLogs('weight');
  const recentHeightLogs = getProcessedLogs('height');

  // --- Get Latest Jump Data ---
  const getLatestJump = (type: JumpType) => {
    const logs = jumpLogs.filter(j => j.type === type).sort((a,b) => new Date(b.date).getTime() - new Date(a.date).getTime());
    return logs.length > 0 ? logs[0].value : 0;
  };

  const squatJumpVal = getLatestJump('squat_jump');
  const cmJumpVal = getLatestJump('cm_jump');
  const dropJumpVal = getLatestJump('drop_jump');
  const jump45sVal = getLatestJump('45s_jump');
  const slLeftVal = getLatestJump('single_leg_left');
  const slRightVal = getLatestJump('single_leg_right');

  const handleEditClick = (log: BodyMetricLog) => {
      setEditingLog(log);
      const displayVal = log.type === 'weight' 
          ? (unitSystem === 'metric' ? log.value : log.value * 2.20462)
          : (unitSystem === 'metric' ? log.value : log.value / 30.48);
      
      setEditValue(displayVal.toFixed(log.type === 'weight' ? 1 : 2));
  };

  const handleSaveEdit = () => {
      if (!editingLog || !onUpdateBodyLog) return;
      const num = parseFloat(editValue);
      if (isNaN(num)) return;

      // Convert back to metric for storage
      let storeVal = num;
      if (editingLog.type === 'weight' && unitSystem === 'imperial') {
          storeVal = num / 2.20462;
      } else if (editingLog.type === 'height' && unitSystem === 'imperial') {
          storeVal = num * 30.48;
      }
      
      onUpdateBodyLog(editingLog.id, storeVal);
      setEditingLog(null);
  };
  
  const handleExerciseNavigation = (id: string) => {
      if(onExerciseClick) onExerciseClick(id);
      else setView('exercise-details');
  };

  const handleJumpNavigation = (type: JumpType) => {
      if(onJumpClick) onJumpClick(type);
  };

  const handleViewAllMetrics = (type: 'weight' | 'height') => {
      if (onBodyMetricsClick) onBodyMetricsClick(type);
  };

  // Shared Render for History List Items
  const renderHistoryItem = (item: { log: BodyMetricLog, trend: string | null, diff: number }, type: 'weight' | 'height') => {
      const { log, trend, diff } = item;
      const displayVal = type === 'weight' 
          ? (unitSystem === 'metric' ? log.value : log.value * 2.20462)
          : (unitSystem === 'metric' ? log.value : log.value / 30.48);
      
      const dateObj = new Date(log.date);
      const day = dateObj.getDate();
      const month = dateObj.toLocaleDateString(language === 'it' ? 'it-IT' : 'en-US', { month: 'short' });
      const isToday = log.date === new Date().toISOString().split('T')[0];

      return (
        <div key={log.id} className={`p-3 rounded-xl border border-white/5 flex items-center justify-between hover:border-white/20 transition group ${isToday ? 'bg-secondary/5' : 'bg-card'}`}>
            <div className="flex items-center gap-3">
                <div className={`flex flex-col items-center justify-center w-10 h-10 rounded-lg ${type === 'weight' ? 'bg-secondary/10 text-secondary' : 'bg-purple-500/10 text-purple-400'}`}>
                    <span className="text-xs font-bold leading-none">{day}</span>
                    <span className="text-[8px] uppercase font-bold">{month}</span>
                </div>
                <div>
                    <div className="flex items-baseline gap-1.5">
                        <span className="text-base font-bold tracking-tight">
                        {displayVal.toFixed(type === 'weight' ? 1 : 2)}
                        </span>
                        <span className="text-[10px] font-bold text-gray-500 uppercase">
                        {type === 'weight' ? weightUnit : heightUnit}
                        </span>
                    </div>
                    {/* Trend Indicator */}
                    {trend && (
                        <div className="flex items-center gap-1">
                            {trend === 'up' && (
                                <>
                                    <ArrowUpRight className={`w-3 h-3 ${type === 'weight' ? 'text-secondary' : 'text-emerald-400'}`} />
                                    <span className={`text-[10px] font-bold ${type === 'weight' ? 'text-secondary' : 'text-emerald-400'}`}>
                                        +{Math.abs(type === 'weight' && unitSystem === 'imperial' ? diff * 2.20462 : diff).toFixed(1)}
                                    </span>
                                </>
                            )}
                            {trend === 'down' && (
                                <>
                                    <ArrowDownRight className={`w-3 h-3 ${type === 'weight' ? 'text-emerald-400' : 'text-red-400'}`} />
                                    <span className={`text-[10px] font-bold ${type === 'weight' ? 'text-emerald-400' : 'text-red-400'}`}>
                                        -{Math.abs(type === 'weight' && unitSystem === 'imperial' ? diff * 2.20462 : diff).toFixed(1)}
                                    </span>
                                </>
                            )}
                            {trend === 'equal' && (
                                <div className="flex items-center gap-1 text-gray-600">
                                    <Minus className="w-3 h-3" />
                                    <span className="text-[10px] font-bold">Stable</span>
                                </div>
                            )}
                        </div>
                    )}
                </div>
            </div>

            {/* Actions */}
            <div className="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                <button 
                onClick={(e) => { e.stopPropagation(); handleEditClick(log); }} 
                className="p-1.5 rounded-lg text-gray-500 hover:text-white hover:bg-white/10 transition"
                >
                    <Edit2 className="w-3.5 h-3.5" />
                </button>
                <button 
                onClick={(e) => { e.stopPropagation(); onDeleteBodyLog && onDeleteBodyLog(log.id); }} 
                className="p-1.5 rounded-lg text-gray-500 hover:text-red-500 hover:bg-red-500/10 transition"
                >
                    <Trash2 className="w-3.5 h-3.5" />
                </button>
            </div>
        </div>
      );
  };

  return (
    <div className="pb-24 pt-4 px-4 min-h-screen bg-background relative">
      
      {/* Edit Modal */}
      {editingLog && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
              <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={() => setEditingLog(null)}></div>
              <div className="bg-card w-full max-w-xs p-6 rounded-2xl border border-white/10 relative z-10 animate-in zoom-in-95">
                  <h3 className="text-lg font-bold mb-4">Edit Entry</h3>
                  <div className="mb-6">
                      <label className="text-xs font-bold text-gray-500 uppercase mb-2 block">{editingLog.type === 'weight' ? 'Weight' : 'Height'}</label>
                      <div className="flex items-center gap-2">
                          <input 
                              type="number" 
                              value={editValue}
                              onChange={(e) => setEditValue(e.target.value)}
                              className="w-full bg-surface border border-white/10 rounded-xl p-3 text-lg font-bold focus:ring-1 focus:ring-secondary"
                              autoFocus
                          />
                          <span className="font-bold text-gray-500">{editingLog.type === 'weight' ? weightUnit : heightUnit}</span>
                      </div>
                  </div>
                  <div className="flex gap-3">
                      <button onClick={() => setEditingLog(null)} className="flex-1 py-3 rounded-xl bg-white/5 font-bold text-sm">Cancel</button>
                      <button onClick={handleSaveEdit} className="flex-1 py-3 rounded-xl bg-secondary text-white font-bold text-sm flex items-center justify-center gap-2">
                          Save <Check className="w-4 h-4" />
                      </button>
                  </div>
              </div>
          </div>
      )}

      <header className="flex justify-between items-center mb-6">
        <h2 className="text-lg font-bold">{t.analytics}</h2>
        <Share className="w-6 h-6 text-gray-400" />
      </header>

      {/* Jump Profile */}
      <section className="mb-8">
        <p className="text-gray-400 text-xs font-bold uppercase tracking-widest mb-3">{t.jumpProfile}</p>
        <div className="grid grid-cols-3 gap-2">
          {/* Box 1: Squat Jump */}
          <div 
             onClick={() => handleJumpNavigation('squat_jump')}
             className="bg-card rounded-xl p-3 border border-white/5 flex flex-col items-center justify-center text-center h-24 cursor-pointer hover:border-white/20 active:scale-[0.98] transition"
          >
            <p className="text-lg font-bold">{squatJumpVal > 0 ? jumpVal(squatJumpVal) : '--'}<span className="text-xs text-gray-400 font-normal">{jumpUnit}</span></p>
            <p className="text-gray-400 text-[9px] font-bold uppercase leading-tight mt-1">{t.squatJump}</p>
          </div>
          
          {/* Box 2: CM Jump */}
          <div 
             onClick={() => handleJumpNavigation('cm_jump')}
             className="bg-card rounded-xl p-3 border border-secondary/50 shadow-[0_0_15px_-5px_rgba(19,164,236,0.3)] flex flex-col items-center justify-center text-center h-24 relative cursor-pointer hover:border-secondary active:scale-[0.98] transition"
          >
             <div className="absolute top-2 right-2 w-1.5 h-1.5 bg-secondary rounded-full"></div>
            <p className="text-lg font-bold">{cmJumpVal > 0 ? jumpVal(cmJumpVal) : '--'}<span className="text-xs text-gray-400 font-normal">{jumpUnit}</span></p>
            <p className="text-gray-400 text-[9px] font-bold uppercase leading-tight mt-1">{t.cmJump}</p>
          </div>
          
          {/* Box 3: Drop Jump */}
          <div 
             onClick={() => handleJumpNavigation('drop_jump')}
             className="bg-card rounded-xl p-3 border border-white/5 flex flex-col items-center justify-center text-center h-24 cursor-pointer hover:border-white/20 active:scale-[0.98] transition"
          >
            <p className="text-lg font-bold">{dropJumpVal > 0 ? jumpVal(dropJumpVal) : '--'}<span className="text-xs text-gray-400 font-normal">{jumpUnit}</span></p>
            <p className="text-gray-400 text-[9px] font-bold uppercase leading-tight mt-1">{t.dropJump}</p>
          </div>
          
           {/* Box 4: 45s Jump */}
           <div 
             onClick={() => handleJumpNavigation('45s_jump')}
             className="bg-card rounded-xl p-3 border border-white/5 flex flex-col items-center justify-center text-center h-24 cursor-pointer hover:border-white/20 active:scale-[0.98] transition"
           >
            <p className="text-lg font-bold">{jump45sVal > 0 ? jumpVal(jump45sVal) : '--'}<span className="text-xs text-gray-400 font-normal">{jumpUnit}</span></p>
            <p className="text-gray-400 text-[9px] font-bold uppercase leading-tight mt-1">45s<br/>Jump</p>
          </div>
          
          {/* Box 5 (Double width): Single Leg */}
          <div className="col-span-2 bg-card rounded-xl border border-white/5 h-24 flex relative overflow-hidden">
             {/* Left Button */}
             <button 
                onClick={() => handleJumpNavigation('single_leg_left')}
                className="flex-1 flex flex-col items-center justify-center hover:bg-white/5 transition active:bg-white/10"
             >
                <p className="text-lg font-bold">{slLeftVal > 0 ? jumpVal(slLeftVal) : '--'}<span className="text-xs text-gray-400 font-normal">{jumpUnit}</span></p>
                <p className="text-gray-400 text-[9px] font-bold uppercase">{t.left}</p>
             </button>

             {/* Divider */}
             <div className="w-px bg-white/10 my-3"></div>

             {/* Right Button */}
             <button 
                onClick={() => handleJumpNavigation('single_leg_right')}
                className="flex-1 flex flex-col items-center justify-center hover:bg-white/5 transition active:bg-white/10"
             >
                <p className="text-lg font-bold">{slRightVal > 0 ? jumpVal(slRightVal) : '--'}<span className="text-xs text-gray-400 font-normal">{jumpUnit}</span></p>
                <p className="text-gray-400 text-[9px] font-bold uppercase">{t.right}</p>
             </button>

             {/* Visual balance bar - Overlay at bottom */}
             <div className="absolute bottom-2 left-1/2 -translate-x-1/2 w-24 h-1 bg-white/10 rounded-full overflow-hidden flex pointer-events-none">
                {(slLeftVal > 0 || slRightVal > 0) && (
                    <>
                        <div 
                            className="h-full bg-secondary transition-all duration-500" 
                            style={{ width: `${(slLeftVal / ((slLeftVal + slRightVal) || 1)) * 100}%` }}
                        ></div>
                    </>
                )}
             </div>
             <p className="absolute bottom-3 left-1/2 -translate-x-1/2 text-[8px] text-gray-600 font-bold uppercase pointer-events-none">{t.singleLeg}</p>
          </div>
        </div>
      </section>

      {/* Max Load */}
      <section className="mb-8">
        <h3 className="text-base font-bold mb-3">{t.maxLoad}</h3>
        <div className="grid grid-cols-2 gap-3">
          {/* Card 1 */}
          <div onClick={() => handleExerciseNavigation('back_squat')} className="bg-card rounded-xl p-4 border border-white/5 cursor-pointer hover:border-white/20 transition group active:scale-[0.98]">
             <div className="flex justify-between items-start mb-2">
                <span className="bg-secondary/10 text-secondary text-[10px] font-bold px-1.5 py-0.5 rounded">PR</span>
                <Dumbbell className="w-4 h-4 text-gray-500" />
             </div>
             <p className="text-gray-400 text-[10px] font-bold uppercase">Back Squat</p>
             <p className="text-xl font-bold">{kgToUnit(145)}<span className="text-xs text-gray-400 ml-1">{weightUnit}</span></p>
          </div>
           {/* Card 2 */}
           <div onClick={() => handleExerciseNavigation('deadlift')} className="bg-card rounded-xl p-4 border border-white/5 cursor-pointer hover:border-white/20 transition active:scale-[0.98]">
             <div className="flex justify-between items-start mb-2">
                <div className="w-1 h-1"></div>
                <Dumbbell className="w-4 h-4 text-gray-500" />
             </div>
             <p className="text-gray-400 text-[10px] font-bold uppercase">Deadlift</p>
             <p className="text-xl font-bold">{kgToUnit(180)}<span className="text-xs text-gray-400 ml-1">{weightUnit}</span></p>
          </div>
           {/* Card 3 (Bench) */}
           <div onClick={() => handleExerciseNavigation('bench_press')} className="bg-card rounded-xl p-4 border border-white/5 cursor-pointer hover:border-white/20 transition active:scale-[0.98]">
             <div className="flex justify-between items-start mb-2">
                <span className="bg-secondary/10 text-secondary text-[10px] font-bold px-1.5 py-0.5 rounded">PR</span>
                <Dumbbell className="w-4 h-4 text-gray-500" />
             </div>
             <p className="text-gray-400 text-[10px] font-bold uppercase">Bench Press</p>
             <p className="text-xl font-bold">{kgToUnit(105)}<span className="text-xs text-gray-400 ml-1">{weightUnit}</span></p>
          </div>
          {/* Card 4 */}
          <div onClick={() => handleExerciseNavigation('clean_and_jerk')} className="bg-card rounded-xl p-4 border border-white/5 cursor-pointer hover:border-white/20 transition active:scale-[0.98]">
             <div className="flex justify-between items-start mb-2">
                <div className="w-1 h-1"></div>
                <Dumbbell className="w-4 h-4 text-gray-500" />
             </div>
             <p className="text-gray-400 text-[10px] font-bold uppercase">Clean & Jerk</p>
             <p className="text-xl font-bold">{kgToUnit(95)}<span className="text-xs text-gray-400 ml-1">{weightUnit}</span></p>
          </div>
        </div>
      </section>

      {/* Recent Sessions */}
      <section className="mb-10">
        <div className="flex justify-between items-center mb-3">
            <h3 className="text-base font-bold">{t.recentSessions}</h3>
            <button 
                onClick={() => setView('all-sessions')}
                className="text-secondary text-xs font-bold uppercase flex items-center hover:underline"
            >
                {t.viewAll} <ChevronRight className="w-3 h-3" />
            </button>
        </div>
        
        <div className="space-y-2">
            {sessions.slice(0, 3).map((session) => {
                const sport = getSportData(session.sportId);
                const SportIcon = sport.icon;
                return (
                  <div 
                    key={session.id} 
                    onClick={() => onSessionClick && onSessionClick(session.id)}
                    className="bg-card p-3 rounded-xl border border-white/5 flex items-center gap-3 cursor-pointer active:scale-[0.98] transition hover:border-white/20"
                  >
                      <div className={`w-10 h-10 rounded-full border-2 ${session.sportId === 'alpine_skiing' ? 'border-secondary' : 'border-orange-500'} flex items-center justify-center`}>
                          <SportIcon className={`w-4 h-4 ${session.sportId === 'alpine_skiing' ? 'text-secondary' : 'text-orange-500'}`} />
                      </div>
                      <div>
                          <h4 className="text-sm font-bold">{sport.name}</h4>
                          <p className="text-xs text-gray-400">
                             {session.date === new Date().toISOString().split('T')[0] ? t.today : session.date} • {session.startTime} • <span className="text-secondary">RPE {session.effort}</span>
                          </p>
                      </div>
                  </div>
                );
            })}
            {sessions.length === 0 && (
                <p className="text-gray-500 text-sm italic">No recent sessions.</p>
            )}
        </div>
      </section>

      {/* Body Composition History (New Layout) */}
      <div className="space-y-8">
          {/* Weight History */}
          <section>
             <div className="flex justify-between items-center mb-3">
                 <div className="flex items-center gap-2">
                    <Scale className="w-4 h-4 text-secondary" />
                    <h3 className="text-base font-bold">{t.weight} History</h3>
                 </div>
                 <button 
                    onClick={() => handleViewAllMetrics('weight')}
                    className="text-secondary text-xs font-bold uppercase flex items-center hover:underline"
                 >
                    {t.viewAll} <ChevronRight className="w-3 h-3" />
                 </button>
             </div>
             
             <div className="space-y-2">
                 {recentWeightLogs.length > 0 ? (
                     recentWeightLogs.map(item => renderHistoryItem(item, 'weight'))
                 ) : (
                     <div className="p-4 bg-card border border-white/5 rounded-xl text-center">
                         <p className="text-gray-500 text-sm italic">No weight data.</p>
                     </div>
                 )}
             </div>
          </section>

          {/* Height History */}
          {isUnder18 && (
            <section>
               <div className="flex justify-between items-center mb-3">
                   <div className="flex items-center gap-2">
                      <Ruler className="w-4 h-4 text-purple-400" />
                      <h3 className="text-base font-bold">{t.height} History</h3>
                   </div>
                   <button 
                      onClick={() => handleViewAllMetrics('height')}
                      className="text-secondary text-xs font-bold uppercase flex items-center hover:underline"
                   >
                      {t.viewAll} <ChevronRight className="w-3 h-3" />
                   </button>
               </div>
               
               <div className="space-y-2">
                   {recentHeightLogs.length > 0 ? (
                       recentHeightLogs.map(item => renderHistoryItem(item, 'height'))
                   ) : (
                       <div className="p-4 bg-card border border-white/5 rounded-xl text-center">
                           <p className="text-gray-500 text-sm italic">No height data.</p>
                       </div>
                   )}
               </div>
            </section>
          )}
      </div>

    </div>
  );
};

export default Analytics;
