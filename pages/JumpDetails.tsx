
import React, { useState, useMemo } from 'react';
import { ArrowLeft, TrendingUp, Plus, X, Trash2, Calendar, Activity } from 'lucide-react';
import { ViewState, UnitSystem, JumpLog, JumpType } from '../types';
import { JumpChart } from '../components/Charts';

interface Props {
  setView: (view: ViewState) => void;
  unitSystem: UnitSystem;
  jumpType?: JumpType;
  jumpLogs?: JumpLog[];
  onAddJump?: (log: JumpLog) => void;
  onDeleteJump?: (id: string) => void;
}

type TimeRange = '1M' | '3M' | '6M' | '1Y' | 'ALL';

const JUMP_LABELS: Record<JumpType, string> = {
    'squat_jump': 'Squat Jump',
    'cm_jump': 'Counter Movement Jump',
    'drop_jump': 'Drop Jump',
    '45s_jump': '45s Jump (Avg)',
    'single_leg_left': 'Single Leg (Left)',
    'single_leg_right': 'Single Leg (Right)'
};

const JumpDetails: React.FC<Props> = ({ 
    setView, 
    unitSystem, 
    jumpType = 'cm_jump', 
    jumpLogs = [],
    onAddJump,
    onDeleteJump
}) => {
  const [timeRange, setTimeRange] = useState<TimeRange>('6M');
  const [showAddModal, setShowAddModal] = useState(false);
  
  // New Log Form State
  const [newValue, setNewValue] = useState('');
  const [newDate, setNewDate] = useState(new Date().toISOString().split('T')[0]);

  const isMetric = unitSystem === 'metric';
  const unit = isMetric ? 'cm' : 'in';
  
  // Helpers for display
  const displayValue = (cm: number) => isMetric ? cm : Math.round(cm * 0.393701 * 10) / 10;
  
  const title = JUMP_LABELS[jumpType];

  // --- Filter Logic ---
  const filteredLogs = useMemo(() => {
      let logs = jumpLogs.filter(l => l.type === jumpType);
      
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
  }, [jumpLogs, jumpType, timeRange]);

  // Chart Data
  const chartData = useMemo(() => {
      return filteredLogs.map(l => ({
          date: new Date(l.date).toLocaleDateString(undefined, { month: 'short', day: 'numeric' }),
          value: displayValue(l.value)
      }));
  }, [filteredLogs, isMetric]);

  // Best Value in this period
  const bestValue = filteredLogs.length > 0 
    ? Math.max(...filteredLogs.map(l => l.value)) 
    : 0;
  
  // Latest Value
  const latestValue = filteredLogs.length > 0 ? filteredLogs[filteredLogs.length - 1].value : 0;

  const handleSave = () => {
      const v = parseFloat(newValue);
      if (isNaN(v) || !onAddJump) return;
      
      const valInCm = isMetric ? v : v / 0.393701;
      
      const newLog: JumpLog = {
          id: Date.now().toString(),
          type: jumpType as JumpType,
          date: newDate,
          value: valInCm
      };
      
      onAddJump(newLog);
      setShowAddModal(false);
      setNewValue('');
  };

  return (
    <div className="pb-8 min-h-screen bg-background relative">
      
      {/* Add Modal */}
      {showAddModal && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
              <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={() => setShowAddModal(false)}></div>
              <div className="bg-card w-full max-w-xs p-6 rounded-2xl border border-white/10 relative z-10 animate-in zoom-in-95">
                  <div className="flex justify-between items-center mb-4">
                      <h3 className="text-lg font-bold">New Measurement</h3>
                      <button onClick={() => setShowAddModal(false)}><X className="text-gray-400" /></button>
                  </div>
                  
                  <div className="space-y-4">
                      <div>
                          <label className="text-xs font-bold text-gray-500 uppercase mb-1 block">Height / Score</label>
                          <div className="flex items-center gap-2">
                              <input 
                                  type="number" 
                                  value={newValue}
                                  onChange={(e) => setNewValue(e.target.value)}
                                  className="w-full bg-surface border border-white/10 rounded-xl p-3 text-lg font-bold focus:ring-1 focus:ring-secondary"
                                  autoFocus
                                  placeholder="0"
                              />
                              <span className="font-bold text-gray-500">{unit}</span>
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
                        onClick={handleSave}
                        disabled={!newValue}
                        className="w-full py-3 rounded-xl bg-secondary text-white font-bold text-sm flex items-center justify-center gap-2 disabled:opacity-50"
                      >
                          Save Entry
                      </button>
                  </div>
              </div>
          </div>
      )}

      <header className="sticky top-0 z-20 flex items-center justify-between bg-background/95 backdrop-blur px-4 py-3 border-b border-white/5">
         <button onClick={() => setView('analytics')} className="w-10 h-10 flex items-center justify-center rounded-full hover:bg-white/10 transition">
            <ArrowLeft />
         </button>
         <h2 className="font-bold text-lg truncate max-w-[200px]">{title}</h2>
         <button 
            onClick={() => setShowAddModal(true)}
            className="w-10 h-10 flex items-center justify-center rounded-full bg-orange-500/10 text-orange-500 hover:bg-orange-500/20 transition"
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
                    className={`flex-1 py-1.5 text-xs font-bold rounded transition-colors ${timeRange === t ? 'bg-orange-500 text-white shadow-lg' : 'text-gray-400 hover:text-white'}`}
                >
                    {t}
                </button>
            ))}
        </div>

        {/* Hero Card */}
        <div className="bg-card rounded-2xl p-6 border border-white/5 relative overflow-hidden mb-6 shadow-xl">
            <div className="absolute top-0 right-0 -mt-8 -mr-8 w-32 h-32 bg-orange-500/10 blur-2xl rounded-full"></div>
            <div className="flex justify-between items-center relative z-10 mb-2">
                <p className="text-sm font-medium text-gray-400 uppercase tracking-wider">Best in Period</p>
                {/* Trend compared to earliest in period */}
                {filteredLogs.length >= 2 && (
                    <div className="flex items-center gap-1 bg-orange-500/10 px-2 py-0.5 rounded text-orange-500">
                        <TrendingUp className="w-3 h-3" />
                        <span className="text-xs font-bold">
                            {displayValue(latestValue - filteredLogs[0].value) > 0 ? '+' : ''}
                            {displayValue(latestValue - filteredLogs[0].value).toFixed(1)} {unit}
                        </span>
                    </div>
                )}
            </div>
            <div className="relative z-10 flex items-baseline gap-2">
                <h1 className="text-5xl font-extrabold tracking-tight">{bestValue > 0 ? displayValue(bestValue) : '--'}</h1>
                <span className="text-xl font-medium text-gray-500">{unit}</span>
            </div>
            <p className="text-xs text-gray-500 mt-2 relative z-10 flex items-center gap-1">
                <Calendar className="w-3 h-3" /> 
                {filteredLogs.length > 0 ? `Latest: ${new Date(filteredLogs[filteredLogs.length-1].date).toLocaleDateString()}` : 'No data in range'}
            </p>
        </div>

        {/* Chart */}
        <div className="mb-6">
            <h3 className="font-bold text-lg mb-4">Progress Trend</h3>
            <div className="h-[220px] bg-gradient-to-b from-card to-transparent rounded-2xl border border-white/5 p-4">
                {chartData.length > 0 ? (
                    <JumpChart data={chartData} />
                ) : (
                    <div className="h-full flex items-center justify-center text-gray-500 text-sm italic">
                        No data available
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
                        <p className="text-xs text-gray-500 mt-0.5 capitalize">{log.type.replace(/_/g, ' ')}</p>
                    </div>
                    <div className="flex items-center gap-4">
                        <p className="font-bold text-xl text-orange-500">{displayValue(log.value)} <span className="text-sm font-medium text-gray-500">{unit}</span></p>
                        <button 
                            onClick={() => onDeleteJump && onDeleteJump(log.id)}
                            className="p-2 text-gray-600 hover:text-red-500 hover:bg-red-500/10 rounded-lg transition"
                        >
                            <Trash2 className="w-4 h-4" />
                        </button>
                    </div>
                </div>
            ))}
            
            {filteredLogs.length === 0 && (
                <div className="text-center py-8 opacity-50">
                    <p className="text-gray-400 text-sm">No measurements recorded.</p>
                </div>
            )}
        </div>
      </div>
    </div>
  );
};

export default JumpDetails;
    