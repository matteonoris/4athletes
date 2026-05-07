
import React, { useState } from 'react';
import { ArrowLeft, Search, Edit2, Trash2, ArrowUpRight, ArrowDownRight, Minus, Scale, Ruler } from 'lucide-react';
import { ViewState, UnitSystem, Language, BodyMetricLog } from '../types';
import { translations } from '../i18n';

interface Props {
  setView: (view: ViewState) => void;
  metricType: 'weight' | 'height';
  bodyLogs: BodyMetricLog[];
  unitSystem: UnitSystem;
  language: Language;
  onDeleteLog?: (id: string) => void;
  onUpdateLog?: (id: string, newVal: number) => void;
}

const AllBodyMetrics: React.FC<Props> = ({ 
    setView, 
    metricType, 
    bodyLogs, 
    unitSystem, 
    language,
    onDeleteLog,
    onUpdateLog 
}) => {
  const t = translations[language];
  const [searchTerm, setSearchTerm] = useState('');
  
  // State for Edit Modal (duplicated logic from Analytics for full functionality)
  const [editingLog, setEditingLog] = useState<BodyMetricLog | null>(null);
  const [editValue, setEditValue] = useState('');

  const weightUnit = unitSystem === 'metric' ? 'kg' : 'lbs';
  const heightUnit = unitSystem === 'metric' ? 'cm' : 'ft';

  // --- Processing Data ---
  // Filter by type
  const logsByType = bodyLogs
    .filter(l => l.type === metricType)
    .sort((a,b) => new Date(b.date).getTime() - new Date(a.date).getTime()); // Newest first

  // Calculate trends before filtering by search
  const processedLogs = logsByType.map((log, index) => {
      let trend: 'up' | 'down' | 'equal' | null = null;
      let diff = 0;
      if (index < logsByType.length - 1) {
          const prevVal = logsByType[index + 1].value;
          diff = log.value - prevVal;
          if (diff > 0) trend = 'up';
          else if (diff < 0) trend = 'down';
          else trend = 'equal';
      }
      return { log, trend, diff };
  });

  // Filter by search
  const filteredLogs = processedLogs.filter(item => 
      item.log.date.includes(searchTerm)
  );

  const handleEditClick = (log: BodyMetricLog) => {
      setEditingLog(log);
      const displayVal = log.type === 'weight' 
          ? (unitSystem === 'metric' ? log.value : log.value * 2.20462)
          : (unitSystem === 'metric' ? log.value : log.value / 30.48);
      setEditValue(displayVal.toFixed(log.type === 'weight' ? 1 : 2));
  };

  const handleSaveEdit = () => {
      if (!editingLog || !onUpdateLog) return;
      const num = parseFloat(editValue);
      if (isNaN(num)) return;

      let storeVal = num;
      if (editingLog.type === 'weight' && unitSystem === 'imperial') {
          storeVal = num / 2.20462;
      } else if (editingLog.type === 'height' && unitSystem === 'imperial') {
          storeVal = num * 30.48;
      }
      
      onUpdateLog(editingLog.id, storeVal);
      setEditingLog(null);
  };

  return (
    <div className="min-h-screen bg-background relative flex flex-col">
      
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
                          Save
                      </button>
                  </div>
              </div>
          </div>
      )}

      <header className="sticky top-0 z-20 bg-background/95 backdrop-blur p-4 pb-2 border-b border-white/5 flex items-center justify-between">
        <button onClick={() => setView('analytics')} className="w-10 h-10 flex items-center justify-center rounded-full hover:bg-white/10 transition">
            <ArrowLeft className="text-white" />
        </button>
        <h1 className="font-bold text-lg flex-1 text-center capitalize">{metricType === 'weight' ? t.weight : t.height} History</h1>
        <div className="w-10"></div>
      </header>

      {/* Search Bar */}
      <div className="p-4 border-b border-white/5 sticky top-[65px] bg-background z-10">
         <div className="relative">
            <Search className="absolute left-3 top-2.5 w-4 h-4 text-gray-500" />
            <input 
                type="text" 
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                placeholder="Search by date (YYYY-MM-DD)..." 
                className="w-full bg-surface border-none rounded-lg py-2 pl-9 pr-4 text-sm text-white focus:ring-1 focus:ring-secondary"
            />
         </div>
      </div>

      <div className="flex-1 p-4 space-y-3 overflow-y-auto">
        {filteredLogs.length > 0 ? (
          filteredLogs.map(({ log, trend, diff }) => {
            const displayVal = metricType === 'weight' 
                ? (unitSystem === 'metric' ? log.value : log.value * 2.20462)
                : (unitSystem === 'metric' ? log.value : log.value / 30.48);
            
            const dateObj = new Date(log.date);
            const day = dateObj.getDate();
            const month = dateObj.toLocaleDateString(language === 'it' ? 'it-IT' : 'en-US', { month: 'short' });
            const year = dateObj.getFullYear();
            const isToday = log.date === new Date().toISOString().split('T')[0];

            return (
              <div 
                key={log.id} 
                className={`p-3 rounded-xl border border-white/5 flex items-center justify-between hover:border-white/20 transition group ${isToday ? 'bg-secondary/5' : 'bg-card'}`}
              >
                <div className="flex items-center gap-4">
                    {/* Date Box */}
                    <div className={`flex flex-col items-center justify-center w-12 h-12 rounded-xl border border-white/5 ${metricType === 'weight' ? 'bg-secondary/10 text-secondary' : 'bg-purple-500/10 text-purple-400'}`}>
                        <span className="text-sm font-bold leading-none">{day}</span>
                        <span className="text-[9px] uppercase font-bold opacity-80">{month}</span>
                        <span className="text-[8px] opacity-60 leading-none">{year}</span>
                    </div>

                    <div>
                        <div className="flex items-baseline gap-1.5">
                            <span className="text-xl font-bold tracking-tight">
                            {displayVal.toFixed(metricType === 'weight' ? 1 : 2)}
                            </span>
                            <span className="text-[10px] font-bold text-gray-500 uppercase">
                            {metricType === 'weight' ? weightUnit : heightUnit}
                            </span>
                        </div>
                        {/* Trend Indicator */}
                        {trend && (
                            <div className="flex items-center gap-1 mt-0.5">
                                {trend === 'up' && (
                                    <>
                                        <ArrowUpRight className={`w-3 h-3 ${metricType === 'weight' ? 'text-secondary' : 'text-emerald-400'}`} />
                                        <span className={`text-[10px] font-bold ${metricType === 'weight' ? 'text-secondary' : 'text-emerald-400'}`}>
                                            +{Math.abs(metricType === 'weight' && unitSystem === 'imperial' ? diff * 2.20462 : diff).toFixed(1)}
                                        </span>
                                    </>
                                )}
                                {trend === 'down' && (
                                    <>
                                        <ArrowDownRight className={`w-3 h-3 ${metricType === 'weight' ? 'text-emerald-400' : 'text-red-400'}`} />
                                        <span className={`text-[10px] font-bold ${metricType === 'weight' ? 'text-emerald-400' : 'text-red-400'}`}>
                                            -{Math.abs(metricType === 'weight' && unitSystem === 'imperial' ? diff * 2.20462 : diff).toFixed(1)}
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

                <div className="flex gap-2">
                    <button 
                        onClick={() => handleEditClick(log)} 
                        className="p-2 rounded-lg text-gray-500 hover:text-white hover:bg-white/10 transition"
                    >
                        <Edit2 className="w-4 h-4" />
                    </button>
                    <button 
                        onClick={() => onDeleteLog && onDeleteLog(log.id)} 
                        className="p-2 rounded-lg text-gray-500 hover:text-red-500 hover:bg-red-500/10 transition"
                    >
                        <Trash2 className="w-4 h-4" />
                    </button>
                </div>
              </div>
            );
          })
        ) : (
          <div className="flex flex-col items-center justify-center py-20 opacity-50">
            <div className="w-16 h-16 bg-white/5 rounded-full flex items-center justify-center mb-4">
                {metricType === 'weight' ? <Scale className="w-8 h-8 text-gray-400" /> : <Ruler className="w-8 h-8 text-gray-400" />}
            </div>
            <p className="text-gray-400">No logs found.</p>
          </div>
        )}
      </div>
    </div>
  );
};

export default AllBodyMetrics;
