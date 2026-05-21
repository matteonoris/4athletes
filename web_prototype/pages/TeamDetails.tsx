import React, { useState, useMemo } from 'react';
import { ArrowLeft, ChevronDown, TrendingUp, TrendingDown, Activity, Clock, Zap, Snowflake, SlidersHorizontal, Trophy, X, Share2, Copy, Check } from 'lucide-react';
import { ViewState, Team } from '../types';

interface Props {
  setView: (view: ViewState) => void;
  team?: Team;
}

// --- Types & Mock Data ---

type MetricType = 'hours' | 'changes_total' | 'changes_sl' | 'changes_gs' | 'changes_sg';
type TimeRange = '7d' | '30d' | 'season';

interface MemberStats {
  id: string;
  name: string;
  role: string;
  image: string;
  baseStats: {
    hours: number;
    changes_sl: number;
    changes_gs: number;
    changes_sg: number;
  };
  trend: 'up' | 'down' | 'stable';
}

const TEAM_MEMBERS: MemberStats[] = [
  { 
    id: '1', name: 'Sarah Jenkins', role: 'Slalom Specialist', trend: 'up',
    image: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100&h=100&fit=crop',
    baseStats: { hours: 18.5, changes_sl: 1200, changes_gs: 400, changes_sg: 0 }
  },
  { 
    id: '2', name: 'Mike Thompson', role: 'All-Rounder', trend: 'stable',
    image: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100&h=100&fit=crop',
    baseStats: { hours: 16.2, changes_sl: 600, changes_gs: 800, changes_sg: 150 }
  },
  { 
    id: '3', name: 'Alex Rivera', role: 'Giant Slalom Focus', trend: 'down',
    image: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100&h=100&fit=crop',
    baseStats: { hours: 15.8, changes_sl: 200, changes_gs: 1100, changes_sg: 300 }
  },
  { 
    id: '4', name: 'Jessica Lee', role: 'Speed Team', trend: 'up',
    image: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=100&h=100&fit=crop',
    baseStats: { hours: 14.5, changes_sl: 0, changes_gs: 500, changes_sg: 600 }
  },
  { 
    id: '5', name: 'Tom Hiddleston', role: 'Technical', trend: 'down',
    image: '',
    baseStats: { hours: 12.0, changes_sl: 800, changes_gs: 300, changes_sg: 0 }
  },
  { 
    id: '6', name: 'Anna Kournikova', role: 'Slalom', trend: 'stable',
    image: '',
    baseStats: { hours: 10.5, changes_sl: 750, changes_gs: 100, changes_sg: 0 }
  },
  { 
    id: '7', name: 'Davide Rossi', role: 'Junior', trend: 'up',
    image: '',
    baseStats: { hours: 18.0, changes_sl: 900, changes_gs: 900, changes_sg: 0 }
  },
  { 
    id: '8', name: 'Marco Verratti', role: 'Speed', trend: 'down',
    image: '',
    baseStats: { hours: 8.0, changes_sl: 0, changes_gs: 200, changes_sg: 400 }
  }
];

const METRICS: { id: MetricType; label: string; shortLabel: string; unit: string; icon: React.ElementType }[] = [
  { id: 'hours', label: 'Volume', shortLabel: 'Hours', unit: 'h', icon: Clock },
  { id: 'changes_total', label: 'Tot. Changes', shortLabel: 'Tot. Dir', unit: '', icon: Activity },
  { id: 'changes_sl', label: 'Slalom', shortLabel: 'SL Changes', unit: '', icon: Zap },
  { id: 'changes_gs', label: 'Giant Slalom', shortLabel: 'GS Changes', unit: '', icon: Snowflake },
  { id: 'changes_sg', label: 'Super G', shortLabel: 'SG Changes', unit: '', icon: Snowflake },
];

const TIME_RANGES: { id: TimeRange; label: string; multiplier: number }[] = [
  { id: '7d', label: 'Last 7 Days', multiplier: 1 },
  { id: '30d', label: 'Last 30 Days', multiplier: 4.2 },
  { id: 'season', label: 'Season 24/25', multiplier: 24 },
];

const TeamDetails: React.FC<Props> = ({ setView, team }) => {
  const [activeMetric, setActiveMetric] = useState<MetricType>('hours');
  const [timeRange, setTimeRange] = useState<TimeRange>('7d');
  const [isTimeDropdownOpen, setIsTimeDropdownOpen] = useState(false);
  const [showFilters, setShowFilters] = useState(false);
  const [isCopied, setIsCopied] = useState(false);

  // --- Logic to process data based on filters ---
  const processedData = useMemo(() => {
    const rangeConfig = TIME_RANGES.find(r => r.id === timeRange)!;
    
    return TEAM_MEMBERS.map(member => {
      const m = rangeConfig.multiplier;
      const randomFactor = 0.9 + Math.random() * 0.2; 
      const effectiveMult = m * randomFactor;

      const stats = {
        hours: parseFloat((member.baseStats.hours * effectiveMult).toFixed(1)),
        changes_sl: Math.round(member.baseStats.changes_sl * effectiveMult),
        changes_gs: Math.round(member.baseStats.changes_gs * effectiveMult),
        changes_sg: Math.round(member.baseStats.changes_sg * effectiveMult),
        changes_total: 0
      };
      stats.changes_total = stats.changes_sl + stats.changes_gs + stats.changes_sg;

      let activeValue = 0;
      if (activeMetric === 'hours') activeValue = stats.hours;
      else activeValue = stats[activeMetric];

      return {
        ...member,
        currentValue: activeValue,
        allStats: stats
      };
    }).sort((a, b) => b.currentValue - a.currentValue);
  }, [activeMetric, timeRange]);

  const topValue = processedData[0]?.currentValue || 1;
  const currentMetricDef = METRICS.find(m => m.id === activeMetric)!;
  const currentTimeDef = TIME_RANGES.find(t => t.id === timeRange)!;

  const teamTotal = processedData.reduce((acc, curr) => acc + curr.currentValue, 0);
  const teamAverage = (teamTotal / processedData.length).toFixed(activeMetric === 'hours' ? 1 : 0);

  const handleShare = async () => {
    const inviteLink = `https://athletepro.app/join/${team?.inviteCode}`;
    const shareText = `Unisciti al mio team "${team?.name}" su Athlete Pro! Codice invito: ${team?.inviteCode}`;

    if (navigator.share) {
      try {
        await navigator.share({
          title: 'Unisciti al Team!',
          text: shareText,
          url: inviteLink,
        });
      } catch (err) {
        console.log('Error sharing:', err);
      }
    } else {
      // Fallback: Copy to clipboard
      try {
          await navigator.clipboard.writeText(`${shareText} - ${inviteLink}`);
          setIsCopied(true);
          setTimeout(() => setIsCopied(false), 2000);
      } catch (err) {
          alert('Impossibile condividere o copiare.');
      }
    }
  };

  return (
    <div className="min-h-screen bg-background relative flex flex-col">
      {/* --- HEADER --- */}
      <header className="sticky top-0 z-30 bg-background/95 backdrop-blur p-4 pb-2 border-b border-white/5 flex items-center justify-between shadow-sm">
        <button onClick={() => setView('teams')} className="w-10 h-10 flex items-center justify-center rounded-full hover:bg-white/10 transition">
            <ArrowLeft />
        </button>
        <div className="flex-1 text-center">
            <h1 className="font-bold text-lg leading-tight truncate px-2">{team?.name || 'Alpine Elite Squad'}</h1>
            <p className="text-[10px] font-bold text-secondary uppercase tracking-widest">{processedData.length} Members</p>
        </div>
        <button 
            onClick={handleShare}
            className="w-10 h-10 flex items-center justify-center rounded-full bg-secondary/10 text-secondary hover:bg-secondary/20 transition active:scale-90"
        >
            <Share2 className="w-5 h-5" />
        </button>
      </header>

      {/* --- INVITE CARD --- */}
      <div className="p-4">
        <div className="bg-gradient-to-r from-secondary/20 to-primary/10 border border-white/10 rounded-2xl p-4 flex items-center justify-between shadow-xl">
            <div>
                <p className="text-[10px] font-black text-gray-400 uppercase tracking-widest mb-1">Invita Membri</p>
                <div className="flex items-center gap-2">
                    <span className="text-xl font-mono font-black tracking-widest text-white">{team?.inviteCode}</span>
                    <button onClick={handleShare} className="p-1 hover:text-secondary transition">
                        {isCopied ? <Check className="w-4 h-4 text-green-500" /> : <Copy className="w-4 h-4" />}
                    </button>
                </div>
            </div>
            <button 
                onClick={handleShare}
                className="bg-white text-black px-4 py-2 rounded-xl text-xs font-bold uppercase tracking-wide hover:bg-gray-200 transition active:scale-95"
            >
                Invia Link
            </button>
        </div>
      </div>

      {/* --- FILTER & CONTROLS BAR --- */}
      <div className="sticky top-[57px] z-20 bg-background/95 backdrop-blur border-b border-white/5 shadow-lg shadow-black/20 flex flex-col">
         
         <div className="flex justify-between items-center px-4 py-3">
             <button 
                onClick={() => setShowFilters(!showFilters)}
                className={`flex items-center gap-2 px-3 py-1.5 rounded-lg border transition-all ${
                    showFilters ? 'bg-secondary text-white border-secondary' : 'bg-white/5 border-white/10 text-gray-400 hover:text-white'
                }`}
             >
                {showFilters ? <X className="w-4 h-4" /> : <SlidersHorizontal className="w-4 h-4" />}
                <span className="text-xs font-bold uppercase">Filtri</span>
             </button>

             <div className="relative">
                 <button 
                    onClick={() => setIsTimeDropdownOpen(!isTimeDropdownOpen)}
                    className="flex items-center gap-2 text-sm font-bold text-white bg-white/5 px-3 py-1.5 rounded-lg hover:bg-white/10 transition"
                 >
                    <Clock className="w-3.5 h-3.5 text-secondary" />
                    {currentTimeDef.label}
                    <ChevronDown className={`w-3.5 h-3.5 transition-transform ${isTimeDropdownOpen ? 'rotate-180' : ''}`} />
                 </button>

                 {isTimeDropdownOpen && (
                    <div className="absolute top-full left-1/2 -translate-x-1/2 mt-2 w-40 bg-card border border-white/10 rounded-xl shadow-xl overflow-hidden z-40 animate-in zoom-in-95">
                        {TIME_RANGES.map((r) => (
                            <button
                                key={r.id}
                                onClick={() => {
                                    setTimeRange(r.id);
                                    setIsTimeDropdownOpen(false);
                                }}
                                className={`w-full text-left px-4 py-3 text-xs font-bold ${timeRange === r.id ? 'bg-secondary/10 text-secondary' : 'text-gray-400 hover:bg-white/5'}`}
                            >
                                {r.label}
                            </button>
                        ))}
                    </div>
                 )}
             </div>

             <div className="text-right">
                <p className="text-[9px] uppercase font-bold text-gray-500">Total</p>
                <p className="text-sm font-bold text-secondary">
                    {teamTotal.toLocaleString()} <span className="text-[10px] text-gray-400">{currentMetricDef.unit}</span>
                </p>
             </div>
         </div>

         {showFilters && (
            <div className="border-t border-white/5 bg-surface/30 animate-in slide-in-from-top-2 duration-200">
                <div className="overflow-x-auto hide-scrollbar px-4 py-3 flex gap-2">
                    {METRICS.map((metric) => (
                        <button 
                            key={metric.id}
                            onClick={() => setActiveMetric(metric.id)}
                            className={`flex items-center gap-2 rounded-full px-4 py-2 text-xs font-bold whitespace-nowrap transition-all duration-300 border ${
                                activeMetric === metric.id 
                                ? 'bg-secondary text-white border-secondary shadow-[0_0_15px_-3px_rgba(19,164,236,0.4)]' 
                                : 'bg-card border-white/10 text-gray-400 hover:text-white hover:bg-white/5'
                            }`}
                        >
                            <metric.icon className="w-3.5 h-3.5" />
                            {metric.shortLabel}
                        </button>
                    ))}
                </div>
            </div>
         )}
      </div>

      {/* --- LEADERBOARD HEADER --- */}
      <div className="flex justify-between px-6 py-4 text-[10px] font-bold uppercase tracking-wider text-gray-500 bg-surface/30 sticky top-[110px] z-10">
        <span>Rank & Athlete</span>
        <span className="text-right">{currentMetricDef.label}</span>
      </div>

      {/* --- LIST --- */}
      <main className="px-4 space-y-3 pb-32 pt-2 flex-1 overflow-y-auto">
        {processedData.map((member, index) => {
             const isTop3 = index < 3;
             const relativePercent = (member.currentValue / topValue) * 100;
             
             return (
                 <div key={member.id} className="group relative bg-card rounded-2xl p-3 border border-white/5 hover:border-secondary/30 active:scale-[0.99] transition-all duration-200 shadow-sm">
                    {index === 0 && <div className="absolute left-0 top-1/2 -translate-y-1/2 w-1 h-12 bg-secondary rounded-r-full shadow-[0_0_10px_rgba(19,164,236,0.5)]"></div>}
                    
                    <div className="flex items-center gap-4">
                        <div className={`w-6 text-center font-bold text-lg flex flex-col items-center justify-center ${
                            index === 0 ? 'text-yellow-400 drop-shadow-md' : 
                            index === 1 ? 'text-gray-300' : 
                            index === 2 ? 'text-amber-700' : 'text-gray-600'
                        }`}>
                            {index === 0 ? <Trophy className="w-5 h-5 mb-1" /> : (index + 1)}
                        </div>

                        <div className="relative shrink-0">
                             {member.image ? (
                                <div className="w-12 h-12 rounded-xl bg-gray-700 bg-cover bg-center border border-white/5" style={{backgroundImage: `url("${member.image}")`}}></div>
                             ) : (
                                <div className="w-12 h-12 rounded-xl bg-white/5 flex items-center justify-center border border-white/5">
                                    <span className="text-lg font-bold text-gray-500">{member.name.charAt(0)}</span>
                                </div>
                             )}
                             
                             <div className={`absolute -bottom-1 -right-1 rounded-full p-0.5 border border-card ${
                                member.trend === 'up' ? 'bg-emerald-500/20 text-emerald-500' : 
                                member.trend === 'down' ? 'bg-red-500/20 text-red-500' : 'bg-gray-500/20 text-gray-400'
                             }`}>
                                {member.trend === 'up' ? <TrendingUp className="w-3 h-3" /> : 
                                 member.trend === 'down' ? <TrendingDown className="w-3 h-3" /> : <div className="w-3 h-0.5 bg-current rounded-full m-1.5"/>}
                             </div>
                        </div>

                        <div className="flex-1 min-w-0">
                            <div className="flex justify-between items-end mb-1">
                                <div>
                                    <p className={`font-bold text-sm truncate ${isTop3 ? 'text-white' : 'text-gray-300'}`}>{member.name}</p>
                                    <p className="text-gray-500 text-[10px] truncate">{member.role}</p>
                                </div>
                                <div className="text-right">
                                    <p className={`text-lg font-bold leading-none ${index === 0 ? 'text-secondary' : 'text-white'}`}>
                                        {member.currentValue.toLocaleString()} <span className="text-[10px] text-gray-400 font-normal ml-0.5">{currentMetricDef.unit}</span>
                                    </p>
                                </div>
                            </div>
                            
                            <div className="w-full h-1.5 bg-black/40 rounded-full overflow-hidden">
                                <div 
                                    className={`h-full rounded-full transition-all duration-1000 ease-out ${
                                        index === 0 ? 'bg-gradient-to-r from-secondary to-cyan-300' : 
                                        'bg-white/10'
                                    }`} 
                                    style={{ width: `${relativePercent}%` }}
                                ></div>
                            </div>
                        </div>
                    </div>
                 </div>
             );
        })}
      </main>

      <div className="sticky bottom-0 z-20 w-full bg-background/90 backdrop-blur-xl border-t border-white/5 p-4 safe-area-bottom">
          <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                  <div className="p-2 rounded-lg bg-secondary/10">
                    <currentMetricDef.icon className="w-5 h-5 text-secondary" />
                  </div>
                  <div>
                      <p className="text-[10px] font-bold uppercase text-gray-400">Team Average</p>
                      <p className="text-base font-bold text-white">{teamAverage} <span className="text-xs font-medium text-gray-500">{currentMetricDef.unit}</span></p>
                  </div>
              </div>
              <div className="h-8 w-px bg-white/10 mx-4"></div>
              <div className="flex-1">
                   <p className="text-[10px] font-bold uppercase text-gray-400 text-right">Top Performer</p>
                   <p className="text-sm font-bold text-white text-right truncate">{processedData[0]?.name}</p>
              </div>
          </div>
      </div>
    </div>
  );
};

export default TeamDetails;