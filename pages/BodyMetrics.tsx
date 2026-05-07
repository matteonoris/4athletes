
import React, { useState, useMemo, useEffect } from 'react';
import { ArrowLeft, TrendingDown, TrendingUp, PlusCircle, Calendar, Clock, Edit3, Check, Minus, Ruler, Monitor } from 'lucide-react';
import { ViewState, UserProfile, BodyMetricLog } from '../types';
import { WeightChart, HeightChart } from '../components/Charts';
import { translations } from '../i18n';

interface Props {
  setView: (view: ViewState) => void;
  userProfile: UserProfile;
  onSaveLog: (val: number, date: string, type: 'weight' | 'height') => void;
  bodyLogs?: BodyMetricLog[];
  initialMetric?: 'weight' | 'height';
}

// Time Range Types
type TimeRange = '1W' | '1M' | '6M' | '1Y' | 'All';
type MetricType = 'weight' | 'height';

const BodyMetrics: React.FC<Props> = ({ setView, userProfile, onSaveLog, bodyLogs = [], initialMetric = 'weight' }) => {
  const t = translations[userProfile.language];
  const isMetric = userProfile.unitSystem === 'metric';
  
  // Calculate Age
  const calculateAge = (birthDateString: string) => {
    const today = new Date();
    const birthDate = new Date(birthDateString);
    let age = today.getFullYear() - birthDate.getFullYear();
    const m = today.getMonth() - birthDate.getMonth();
    if (m < 0 || (m === 0 && today.getDate() < birthDate.getDate())) {
        age--;
    }
    return age;
  };

  const age = calculateAge(userProfile.birthDate);
  const isUnder18 = age < 18;

  // Toggle State
  const [activeMetric, setActiveMetric] = useState<MetricType>(initialMetric);

  useEffect(() => {
    setActiveMetric(initialMetric);
  }, [initialMetric]);

  // Current Values Display Logic
  const currentWeightVal = isMetric ? userProfile.weight : (userProfile.weight * 2.20462);
  const currentHeightVal = isMetric ? userProfile.height : (userProfile.height / 30.48); 
  
  const weightUnit = isMetric ? 'kg' : 'lbs';
  const heightUnit = isMetric ? 'cm' : 'ft';

  // Input State
  const [inputWeight, setInputWeight] = useState<string>(currentWeightVal.toFixed(1));
  const [inputHeight, setInputHeight] = useState<string>(currentHeightVal.toFixed(isMetric ? 0 : 2));
  
  const [selectedRange, setSelectedRange] = useState<TimeRange>('6M');
  const [selectedDate, setSelectedDate] = useState(() => new Date().toISOString().split('T')[0]);

  // --- CHART DATA GENERATOR (Real Data) ---
  const chartData = useMemo(() => {
     // Filter logs by type
     const logs = bodyLogs
        .filter(l => l.type === activeMetric)
        .sort((a,b) => new Date(a.date).getTime() - new Date(b.date).getTime());

     if (logs.length === 0) return [];

     // Filter by Range (Simplified logic)
     const now = new Date();
     let cutoffDate = new Date();
     
     switch(selectedRange) {
         case '1W': cutoffDate.setDate(now.getDate() - 7); break;
         case '1M': cutoffDate.setMonth(now.getMonth() - 1); break;
         case '6M': cutoffDate.setMonth(now.getMonth() - 6); break;
         case '1Y': cutoffDate.setFullYear(now.getFullYear() - 1); break;
         case 'All': cutoffDate = new Date(0); break; // Epoch
     }

     const filteredLogs = logs.filter(l => new Date(l.date) >= cutoffDate);
     
     // Map to Recharts format
     return filteredLogs.map(log => {
         const d = new Date(log.date);
         let label = '';
         
         if (selectedRange === '1W' || selectedRange === '1M') {
             label = d.toLocaleDateString(userProfile.language === 'it' ? 'it-IT' : 'en-US', { day: 'numeric', month: 'short' });
         } else {
             label = d.toLocaleDateString(userProfile.language === 'it' ? 'it-IT' : 'en-US', { month: 'short' });
         }

         if (activeMetric === 'weight') {
             // Convert kg to display unit
             const val = isMetric ? log.value : log.value * 2.20462;
             return { date: label, weight: parseFloat(val.toFixed(1)), bodyFat: 15 }; 
         } else {
             const val = isMetric ? log.value : log.value / 30.48;
             return { date: label, height: parseFloat(val.toFixed(2)) };
         }
     });

  }, [bodyLogs, activeMetric, selectedRange, isMetric, userProfile.language]);


  // --- TREND CALCULATION ---
  // @ts-ignore
  const firstPoint = chartData.length > 0 ? (activeMetric === 'weight' ? chartData[0].weight : chartData[0].height) : 0;
  // @ts-ignore
  const lastPoint = chartData.length > 0 ? (activeMetric === 'weight' ? chartData[chartData.length - 1].weight : chartData[chartData.length - 1].height) : 0;
  
  const diff = lastPoint - firstPoint;
  const absDiff = Math.abs(diff).toFixed(1);
  const isDown = diff < 0;
  const isFlat = diff === 0;

  const getTrendLabel = () => {
      switch(selectedRange) {
          case '1W': return isMetric ? 'settimana' : 'week';
          case '1M': return isMetric ? 'mese' : 'month';
          case '6M': return '6 ' + (isMetric ? 'mesi' : 'months');
          case '1Y': return isMetric ? 'anno' : 'year';
          default: return isMetric ? 'inizio' : 'start';
      }
  };

  const handleSave = () => {
    // Save logic
    if (activeMetric === 'weight') {
        const val = parseFloat(inputWeight);
        if (!isNaN(val)) {
            const weightInKg = isMetric ? val : val / 2.20462;
            onSaveLog(weightInKg, selectedDate, 'weight');
            setView('home');
        }
    } else {
        const val = parseFloat(inputHeight);
        if (!isNaN(val)) {
            const heightInCm = isMetric ? val : val * 30.48;
            onSaveLog(heightInCm, selectedDate, 'height');
            setView('home');
        }
    }
  };

  const ranges: TimeRange[] = ['1W', '1M', '6M', '1Y', 'All'];

  return (
    <div className="pb-24 min-h-screen bg-background relative">
       <header className="sticky top-0 z-20 flex items-center bg-background/95 backdrop-blur px-4 py-3 border-b border-white/5">
         <button onClick={() => setView('home')} className="w-10 h-10 flex items-center justify-center rounded-full hover:bg-white/10 transition">
            <ArrowLeft />
         </button>
         <h2 className="flex-1 text-center font-bold text-lg pr-10">{t.vitals}</h2>
      </header>

      <main className="pt-4 flex flex-col gap-6">
        
        {/* Metric Toggle for Under 18 */}
        {isUnder18 && (
            <div className="px-4">
                <div className="flex bg-surface rounded-xl p-1 border border-white/5">
                    <button 
                        onClick={() => setActiveMetric('weight')}
                        className={`flex-1 py-2 rounded-lg text-sm font-bold transition-all ${activeMetric === 'weight' ? 'bg-card shadow text-secondary border border-white/10' : 'text-gray-500 hover:text-white'}`}
                    >
                        {t.weight}
                    </button>
                    <button 
                        onClick={() => setActiveMetric('height')}
                        className={`flex-1 py-2 rounded-lg text-sm font-bold transition-all ${activeMetric === 'height' ? 'bg-card shadow text-purple-400 border border-white/10' : 'text-gray-500 hover:text-white'}`}
                    >
                        {t.height}
                    </button>
                </div>
            </div>
        )}

        {/* Main Stats Header */}
        <section className="px-4 text-center animate-in fade-in zoom-in-95 duration-300">
            <h1 className="text-5xl font-bold tracking-tighter">
                {activeMetric === 'weight' ? inputWeight : inputHeight} 
                <span className="text-2xl font-medium text-gray-500 ml-1">
                    {activeMetric === 'weight' ? weightUnit : heightUnit}
                </span>
            </h1>
            
            <div className={`inline-flex items-center gap-1 mt-2 px-3 py-1 rounded-full ${
                isFlat ? 'bg-gray-800' : 
                (activeMetric === 'weight' && isDown) ? 'bg-emerald-500/10' : 
                (activeMetric === 'height' && !isDown) ? 'bg-emerald-500/10' : 
                (activeMetric === 'height' && isDown) ? 'bg-red-500/10' : 
                'bg-secondary/10' 
            }`}>
                {isFlat ? (
                    <Minus className="w-4 h-4 text-gray-400" />
                ) : (
                    isDown ? <TrendingDown className={`w-4 h-4 ${activeMetric === 'height' ? 'text-red-500' : 'text-emerald-500'}`} /> : 
                             <TrendingUp className={`w-4 h-4 ${activeMetric === 'height' ? 'text-emerald-500' : 'text-secondary'}`} />
                )}
                <span className={`text-sm font-medium ${
                    isFlat ? 'text-gray-400' : 
                    (activeMetric === 'height') ? (isDown ? 'text-red-500' : 'text-emerald-500') :
                    (isDown ? 'text-emerald-500' : 'text-secondary')
                }`}>
                    {isFlat ? 'No change' : `${absDiff} ${activeMetric === 'weight' ? weightUnit : heightUnit}`} <span className="opacity-70 text-xs">vs last {getTrendLabel()}</span>
                </span>
            </div>
        </section>

        {/* Interactive Chart Section */}
        <section className="w-full h-64 px-4 flex flex-col">
             {/* Range Selectors */}
             <div className="flex justify-between gap-1 p-1 bg-surface rounded-xl mb-4 border border-white/5">
                {ranges.map((r) => (
                    <button 
                        key={r} 
                        onClick={() => setSelectedRange(r)}
                        className={`flex-1 py-1.5 rounded-lg text-xs font-bold transition-all duration-200 ${
                            selectedRange === r 
                            ? `bg-card ${activeMetric === 'weight' ? 'text-secondary' : 'text-purple-400'} shadow-lg shadow-black/20 border border-white/5` 
                            : 'text-gray-500 hover:text-gray-300 hover:bg-white/5'
                        }`}
                    >
                        {r}
                    </button>
                ))}
             </div>
             
             {/* Chart */}
             <div className="flex-1 w-full min-h-0">
                {activeMetric === 'weight' ? (
                    // @ts-ignore
                    <WeightChart data={chartData} />
                ) : (
                    // @ts-ignore
                    <HeightChart data={chartData} />
                )}
             </div>
        </section>

        <div className="h-px bg-white/5 my-2 mx-4"></div>

        {/* Data Entry Section */}
        <section className="px-4 pb-4 space-y-4 animate-in slide-in-from-bottom-4 duration-500 delay-100">
            <div className="flex items-center gap-2 mb-2">
                <PlusCircle className={activeMetric === 'weight' ? 'text-secondary' : 'text-purple-400'} />
                <h3 className="font-semibold">{t.newEntry}</h3>
            </div>

            <div className="bg-card p-4 rounded-xl border border-white/5 focus-within:border-secondary/50 transition-colors">
                <label className="text-xs font-medium text-gray-500 uppercase tracking-wider block mb-2">
                    {activeMetric === 'weight' ? t.weight : t.height}
                </label>
                <div className="flex items-baseline gap-2">
                    <input 
                        type="number" 
                        value={activeMetric === 'weight' ? inputWeight : inputHeight} 
                        onChange={(e) => activeMetric === 'weight' ? setInputWeight(e.target.value) : setInputHeight(e.target.value)}
                        className="bg-transparent border-none p-0 text-3xl font-bold text-white focus:ring-0 w-full placeholder-gray-700" 
                    />
                    <span className="text-lg text-gray-500">{activeMetric === 'weight' ? weightUnit : heightUnit}</span>
                </div>
            </div>

            {activeMetric === 'weight' && (
                <div className="grid grid-cols-2 gap-4">
                    <div className="bg-card p-4 rounded-xl border border-white/5">
                        <label className="text-xs font-medium text-gray-500 mb-1 block">Body Fat</label>
                        <div className="flex items-baseline gap-1">
                            <input type="number" placeholder="16.5" className="bg-transparent border-none p-0 text-xl font-semibold w-full focus:ring-0 placeholder-gray-700" />
                            <span className="text-sm text-gray-500">%</span>
                        </div>
                    </div>
                     <div className="bg-card p-4 rounded-xl border border-white/5">
                        <label className="text-xs font-medium text-gray-500 mb-1 block">{t.leanMass}</label>
                        <div className="flex items-baseline gap-1">
                            <input type="number" placeholder="--" className="bg-transparent border-none p-0 text-xl font-semibold w-full focus:ring-0 placeholder-gray-700" />
                            <span className="text-sm text-gray-500">{weightUnit}</span>
                        </div>
                    </div>
                </div>
            )}

            <div className="bg-card p-4 rounded-xl border border-white/5 space-y-4">
                <div className="flex justify-between items-center border-b border-white/5 pb-3">
                    <div className="flex items-center gap-3">
                        <div className={`w-8 h-8 rounded-lg ${activeMetric === 'weight' ? 'bg-secondary/10' : 'bg-purple-500/10'} flex items-center justify-center`}>
                            <Calendar className={`w-4 h-4 ${activeMetric === 'weight' ? 'text-secondary' : 'text-purple-400'}`} />
                        </div>
                        <span className="text-sm font-medium">{t.date}</span>
                    </div>
                    {/* Date Input */}
                    <input 
                        type="date"
                        value={selectedDate}
                        onChange={(e) => setSelectedDate(e.target.value)}
                        className={`bg-transparent ${activeMetric === 'weight' ? 'text-secondary' : 'text-purple-400'} font-medium text-sm text-right border-none p-0 focus:ring-0 cursor-pointer`}
                    />
                </div>
                <div className="flex justify-between items-center">
                    <div className="flex items-center gap-3">
                        <div className={`w-8 h-8 rounded-lg ${activeMetric === 'weight' ? 'bg-secondary/10' : 'bg-purple-500/10'} flex items-center justify-center`}>
                            <Clock className={`w-4 h-4 ${activeMetric === 'weight' ? 'text-secondary' : 'text-purple-400'}`} />
                        </div>
                        <span className="text-sm font-medium">{t.time}</span>
                    </div>
                    <span className={`text-sm font-medium ${activeMetric === 'weight' ? 'text-secondary' : 'text-purple-400'}`}>{new Date().toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})}</span>
                </div>
            </div>
             <div className="bg-card p-4 rounded-xl border border-white/5">
                 <label className="flex items-center gap-2 text-xs font-medium text-gray-500 uppercase mb-3">
                    <Edit3 className="w-4 h-4" /> {t.notes}
                 </label>
                 <textarea className="w-full bg-surface border-none rounded-lg text-sm text-white placeholder-gray-600 h-24 p-3 resize-none focus:ring-1 focus:ring-secondary" placeholder={t.notesPlaceholder}></textarea>
             </div>
        </section>
      </main>

      <div className="fixed bottom-0 left-0 right-0 p-4 bg-gradient-to-t from-background via-background to-transparent z-40 pb-6">
         <button onClick={handleSave} className={`w-full flex items-center justify-center gap-2 ${activeMetric === 'weight' ? 'bg-secondary hover:bg-sky-500' : 'bg-purple-600 hover:bg-purple-500'} text-white font-bold py-4 rounded-xl shadow-lg transition active:scale-[0.98]`}>
            <Check className="w-5 h-5" /> {t.saveEntry}
         </button>
      </div>
    </div>
  );
};

export default BodyMetrics;
