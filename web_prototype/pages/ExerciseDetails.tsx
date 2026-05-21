
import React, { useState, useMemo } from 'react';
import { ArrowLeft, ChevronDown, SlidersHorizontal, TrendingUp, ChevronRight, Plus, X, Trash2, Calendar } from 'lucide-react';
import { ViewState, UnitSystem, PRLog } from '../types';
import { PRChart } from '../components/Charts';
import { exerciseDatabase } from '../data/exercises';

interface Props {
  setView: (view: ViewState) => void;
  unitSystem: UnitSystem;
  exerciseId?: string;
  prLogs?: PRLog[];
  onAddPR?: (log: PRLog) => void;
  onDeletePR?: (id: string) => void;
}

type TimeRange = '1M' | '3M' | '6M' | '1Y' | 'ALL';

const ExerciseDetails: React.FC<Props> = ({ 
    setView, 
    unitSystem, 
    exerciseId = 'back_squat', 
    prLogs = [],
    onAddPR,
    onDeletePR
}) => {
  const [timeRange, setTimeRange] = useState<TimeRange>('6M');
  const [showAddModal, setShowAddModal] = useState(false);
  
  // New PR Form State
  const [newWeight, setNewWeight] = useState('');
  const [newDate, setNewDate] = useState(new Date().toISOString().split('T')[0]);

  const isMetric = unitSystem === 'metric';
  const weightUnit = isMetric ? 'kg' : 'lbs';
  
  // Helpers for display
  const displayWeight = (kg: number) => isMetric ? kg : Math.round(kg * 2.20462 * 10) / 10;
  
  const exerciseName = exerciseDatabase.find(e => e.id === exerciseId)?.name || 
                       exerciseId.split('_').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');

  // --- Filter Logic ---
  const filteredLogs = useMemo(() => {
      let logs = prLogs.filter(l => l.exerciseId === exerciseId);
      
      const now = new Date();
      let cutoff = new Date();
      
      switch(timeRange) {
          case '1M': cutoff.setMonth(now.getMonth() - 1); break;
          case '3M': cutoff.setMonth(now.getMonth() - 3); break;
          case '6M': cutoff.setMonth(now.getMonth() - 6); break;
          case '1Y': cutoff.setFullYear(now.getFullYear() - 1); break;
          case 'ALL': cutoff = new Date(0); break;
      }
      
      return logs.filter(l => new Date(l.date) >= cutoff).sort((a,b) => new Date(a.date).getTime() - new Date(b.date).getTime());
  }, [prLogs, exerciseId, timeRange]);

  // Chart Data
  const chartData = useMemo(() => {
      return filteredLogs.map(l => ({
          date: new Date(l.date).toLocaleDateString(undefined, { month: 'short', day: 'numeric' }),
          weight: displayWeight(l.weight)
      }));
  }, [filteredLogs, isMetric]);

  // Current Max in this period
  const currentMax = filteredLogs.length > 0 
    ? Math.max(...filteredLogs.map(l => l.weight)) 
    : 0;
    
  // Compare with previous period (simple logic: compare max of first half vs second half of logs or just last entry vs prev)
  // Let's use All-Time PR logic for the "Hero" card usually, but user wants dynamic.
  // We'll show the MAX of the selected period.
  
  const handleSavePR = () => {
      const w = parseFloat(newWeight);
      if (isNaN(w) || !onAddPR) return;
      
      const weightInKg = isMetric ? w : w / 2.20462;
      
      const newLog: PRLog = {
          id: Date.now().toString(),
          exerciseId,
          date: newDate,
          weight: weightInKg
      };
      
      onAddPR(newLog);
      setShowAddModal(false);
      setNewWeight('');
  };

  return (
    <div className="pb-8 min-h-screen bg-background relative">
      
      {/* Add PR Modal */}
      {showAddModal && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
              <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={() => setShowAddModal(false)}></div>
              <div className="bg-card w-full max-w-xs p-6 rounded-2xl border border-white/10 relative z-10 animate-in zoom-in-95">
                  <div className="flex justify-between items-center mb-4">
                      <h3 className="text-lg font-bold">Add New PR</h3>
                      <button onClick={() => setShowAddModal(false)}><X className="text-gray-400" /></button>
                  </div>
                  
                  <div className="space-y-4">
                      <div>
                          <label className="text-xs font-bold text-gray-500 uppercase mb-1 block">Weight</label>
                          <div className="flex items-center gap-2">
                              <input 
                                  type="number" 
                                  value={newWeight}
                                  onChange={(e) => setNewWeight(e.target.value)}
                                  className="w-full bg-surface border border-white/10 rounded-xl p-3 text-lg font-bold focus:ring-1 focus:ring-secondary"
                                  autoFocus
                                  placeholder="0"
                              />
                              <span className="font-bold text-gray-500">{weightUnit}</span>
                          </div>
                      </div>
                      <div>
                          <label className="text-xs font-bold text-gray-500 uppercase mb-1 block">Date</label>
                          <input 
                              type="date" 
                              value={newDate}
                              onChange={(e) => setNewDate(e.target.value)}
                              className="w-full bg-surface border border-white/10 rounded-xl p-3 text-sm font-bold text-white focus:ring-1 focus:ring-secondary"
                          />
                      </div>
                      
                      <button 
                        onClick={handleSavePR}
                        disabled={!newWeight}
                        className="w-full py-3 rounded-xl bg-secondary text-white font-bold text-sm flex items-center justify-center gap-2 disabled:opacity-50"
                      >
                          Save Record
                      </button>
                  </div>
              </div>
          </div>
      )}

      <header className="sticky top-0 z-20 flex items-center justify-between bg-background/95 backdrop-blur px-4 py-3 border-b border-white/5">
         <button onClick={() => setView('analytics')} className="w-10 h-10 flex items-center justify-center rounded-full hover:bg-white/10 transition">
            <ArrowLeft />
         </button>
         <button className="flex items-center gap-2 px-4 py-2 hover:bg-white/5 rounded-full transition">
            <h2 className="font-bold text-lg truncate max-w-[200px]">{exerciseName}</h2>
         </button>
         <button 
            onClick={() => setShowAddModal(true)}
            className="w-10 h-10 flex items-center justify-center rounded-full bg-secondary/10 text-secondary hover:bg-secondary/20 transition"
         >
            <Plus className="w-6 h-6" />
         </button>
      </header>

      <div className="px-4 py-4">
        {/* Time Range Selector */}
        <div className="bg-surface rounded-lg p-1 border border-white/5 flex mb-4">
            {(['1M', '3M', '6M', '1Y', 'ALL'] as TimeRange[]).map((t) => (
                <button 
                    key={t} 
                    onClick={() => setTimeRange(t)}
                    className={`flex-1 py-1.5 text-xs font-bold rounded transition-colors ${timeRange === t ? 'bg-secondary text-white shadow-lg' : 'text-gray-400 hover:text-white'}`}
                >
                    {t}
                </button>
            ))}
        </div>

        {/* Hero Card */}
        <div className="bg-card rounded-2xl p-6 border border-white/5 relative overflow-hidden mb-6 shadow-xl">
            <div className="absolute top-0 right-0 -mt-8 -mr-8 w-32 h-32 bg-primary/10 blur-2xl rounded-full"></div>
            <div className="flex justify-between items-center relative z-10 mb-2">
                <p className="text-sm font-medium text-gray-400 uppercase tracking-wider">Period Max</p>
                {/* Calculate trend simply based on first vs last of period for now */}
                {filteredLogs.length >= 2 && (
                    <div className="flex items-center gap-1 bg-primary/10 px-2 py-0.5 rounded text-primary">
                        <TrendingUp className="w-3 h-3" />
                        <span className="text-xs font-bold">
                            {displayWeight(filteredLogs[filteredLogs.length-1].weight - filteredLogs[0].weight) > 0 ? '+' : ''}
                            {displayWeight(filteredLogs[filteredLogs.length-1].weight - filteredLogs[0].weight).toFixed(1)} {weightUnit}
                        </span>
                    </div>
                )}
            </div>
            <div className="relative z-10 flex items-baseline gap-2">
                <h1 className="text-5xl font-extrabold tracking-tight">{currentMax > 0 ? displayWeight(currentMax) : '--'}</h1>
                <span className="text-xl font-medium text-gray-500">{weightUnit}</span>
            </div>
            <p className="text-xs text-gray-500 mt-2 relative z-10 flex items-center gap-1">
                <Calendar className="w-3 h-3" /> 
                {filteredLogs.length > 0 ? `Last set: ${filteredLogs[filteredLogs.length-1].date}` : 'No data in range'}
            </p>
        </div>

        {/* Chart */}
        <div className="mb-6">
            <h3 className="font-bold text-lg mb-4">Performance Trend</h3>
            <div className="h-[220px] bg-gradient-to-b from-card to-transparent rounded-2xl border border-white/5 p-4">
                {chartData.length > 0 ? (
                    <PRChart data={chartData} />
                ) : (
                    <div className="h-full flex items-center justify-center text-gray-500 text-sm italic">
                        No data available for this period
                    </div>
                )}
            </div>
        </div>

        {/* History List */}
        <div className="space-y-4">
            <h3 className="font-bold text-lg">History ({filteredLogs.length})</h3>
            {[...filteredLogs].reverse().map((log) => (
                <div key={log.id} className="flex justify-between items-center p-4 bg-card rounded-xl border border-white/5 hover:border-white/20 transition group">
                    <div>
                        <p className="font-semibold text-sm text-white">{new Date(log.date).toLocaleDateString(undefined, { weekday: 'short', month: 'long', day: 'numeric' })}</p>
                        <p className="text-xs text-gray-500 mt-0.5">1 Rep Max</p>
                    </div>
                    <div className="flex items-center gap-4">
                        <p className="font-bold text-xl text-secondary">{displayWeight(log.weight)} <span className="text-sm font-medium text-gray-500">{weightUnit}</span></p>
                        <button 
                            onClick={() => onDeletePR && onDeletePR(log.id)}
                            className="p-2 text-gray-600 hover:text-red-500 hover:bg-red-500/10 rounded-lg transition"
                        >
                            <Trash2 className="w-4 h-4" />
                        </button>
                    </div>
                </div>
            ))}
            
            {filteredLogs.length === 0 && (
                <div className="text-center py-8 opacity-50">
                    <p className="text-gray-400 text-sm">No records found.</p>
                </div>
            )}
        </div>
      </div>
    </div>
  );
};

export default ExerciseDetails;
