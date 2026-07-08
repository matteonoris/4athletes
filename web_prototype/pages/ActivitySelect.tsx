
import React, { useState, useMemo } from 'react';
import {
  ChevronLeft,
  Search,
  Plus,
  Dumbbell,
  Zap,
  Timer,
  HeartPulse,
  Move,
  Repeat,
} from 'lucide-react';
import { ViewState } from '../types';
import { sportsData } from '../data/sports';

interface Props {
  setView: (view: ViewState) => void;
  onSelectSport?: (id: string) => void;
}

const ActivitySelect: React.FC<Props> = ({ setView, onSelectSport }) => {
  const [searchTerm, setSearchTerm] = useState('');
  const [activeTab, setActiveTab] = useState('All');

  const categories = ['All', 'Winter', 'Team', 'Endurance', 'Combat', 'Racquet', 'Water', 'Skill'];
  const prepTypes = [
    { id: 'strength', name: 'Forza', note: 'Palestra, kg, reps, RPE', icon: Dumbbell },
    { id: 'plyometrics', name: 'Pliometria', note: 'Balzi, contatti, reattivita', icon: Zap },
    { id: 'speed_agility', name: 'Velocita / Agilita', note: 'Sprint, cambi, ostacoli', icon: Timer },
    { id: 'endurance', name: 'Resistenza', note: 'Corsa, cardio, zone', icon: HeartPulse },
    { id: 'mobility_core', name: 'Mobilita / Core', note: 'Stabilita, controllo, ROM', icon: Move },
    { id: 'mixed_circuit', name: 'Misto / Circuito', note: 'Blocchi combinati', icon: Repeat },
  ];

  const filteredSports = useMemo(() => {
    let filtered = sportsData.filter(
      s => s.category !== 'Fitness' || s.id === 'hyperarch' || s.id === 'tendon_isometrics'
    );
    
    // Filter by Tab
    if (activeTab !== 'All') {
      filtered = filtered.filter(s => s.category === activeTab);
    }

    // Filter by Search
    if (searchTerm) {
      const lower = searchTerm.toLowerCase();
      filtered = filtered.filter(s => s.name.toLowerCase().includes(lower));
    }

    // Sort alphabetically
    return filtered.sort((a, b) => a.name.localeCompare(b.name));
  }, [searchTerm, activeTab]);

  const handleSportSelect = (sportId: string) => {
    if (onSelectSport) {
        onSelectSport(sportId);
    } else {
        // Fallback for direct navigation if needed
        if (sportId === 'alpine_skiing') {
            setView('add-training-skiing');
        } else {
            setView('add-training');
        }
    }
  };

  return (
    <div className="fixed inset-0 z-50 bg-background flex flex-col">
      <header className="p-4 pt-8 bg-surface/50 backdrop-blur-md border-b border-white/5">
        <div className="relative flex items-center justify-center mb-6">
             <button onClick={() => setView('add-training')} className="absolute left-0 p-2 hover:bg-white/10 rounded-full">
                <ChevronLeft />
             </button>
             <h1 className="text-sm font-bold uppercase tracking-widest">Select Your Activity</h1>
        </div>
        
        {/* Search Bar */}
        <div className="relative group mb-4">
            <Search className="absolute left-4 top-3.5 w-5 h-5 text-gray-400 group-focus-within:text-secondary transition-colors" />
            <input 
              type="text" 
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              placeholder="Search 60+ sports..."
              className="w-full bg-black/20 border border-white/10 rounded-xl py-3.5 pl-12 pr-4 text-sm focus:ring-1 focus:ring-secondary focus:border-secondary transition-all text-white placeholder-gray-500" 
            />
        </div>

        {/* Categories */}
        <div className="flex gap-4 overflow-x-auto hide-scrollbar pb-2">
            {categories.map((tab) => (
                <button 
                  key={tab} 
                  onClick={() => setActiveTab(tab)}
                  className={`pb-2 text-xs font-bold tracking-wider border-b-2 whitespace-nowrap transition-colors ${
                    activeTab === tab 
                    ? 'border-secondary text-white' 
                    : 'border-transparent text-gray-500 hover:text-gray-300'
                  }`}
                >
                    {tab.toUpperCase()}
                </button>
            ))}
        </div>
      </header>

      <div className="flex-1 overflow-y-auto px-4 pb-8 space-y-4 pt-4">
         {!searchTerm && (
           <section>
             <h2 className="text-xs font-black uppercase tracking-widest text-gray-500 mb-3">Scegli area</h2>
             <button onClick={() => setActiveTab('All')} className="w-full flex items-center p-4 bg-card rounded-xl border border-white/10 text-left">
                <div className="w-10 h-10 flex items-center justify-center mr-4 text-secondary bg-secondary/10 rounded-lg shrink-0">
                    <Plus className="w-6 h-6" />
                </div>
                <div>
                  <span className="text-sm font-bold uppercase tracking-wide block">Sport</span>
                  <span className="text-xs text-gray-400">Hiking, calcio, corsa, tennis, bici.</span>
                </div>
             </button>
           </section>
         )}

         <section>
           <h2 className="text-xs font-black uppercase tracking-widest text-gray-500 mb-3">Preparazione atletica</h2>
           <div className="grid grid-cols-2 gap-3">
             {prepTypes.map((type) => (
               <button key={type.id} onClick={() => handleSportSelect('athletic_prep')} className="p-4 bg-card rounded-xl border border-white/10 text-left active:scale-[0.98] transition">
                  <type.icon className="w-5 h-5 text-secondary mb-3" />
                  <span className="text-sm font-bold block">{type.name}</span>
                  <span className="text-[11px] text-gray-500 line-clamp-1">{type.note}</span>
               </button>
             ))}
           </div>
         </section>
         
         {filteredSports.length > 0 ? (
           <section className="space-y-2">
           <h2 className="text-xs font-black uppercase tracking-widest text-gray-500 mb-3">Sport</h2>
           {filteredSports.map((sport) => (
             <button key={sport.id} onClick={() => handleSportSelect(sport.id)} className="w-full flex items-center p-4 bg-card rounded-xl active:scale-[0.98] transition hover:bg-white/5 border border-transparent hover:border-white/10 text-left group">
                <div className="w-10 h-10 flex items-center justify-center mr-4 text-gray-400 bg-white/5 rounded-lg group-hover:text-secondary group-hover:bg-secondary/10 transition-colors shrink-0">
                    <sport.icon className="w-6 h-6" />
                </div>
                <div className="flex-1">
                  <span className="text-sm font-bold uppercase tracking-wide block">{sport.name}</span>
                  <span className="text-[10px] text-gray-600 font-mono">{sport.category.toUpperCase()}</span>
                </div>
                <div className="opacity-0 group-hover:opacity-100 transition-opacity">
                    <Plus className="w-5 h-5 text-secondary" />
                </div>
             </button>
           ))}
           </section>
         ) : (
           <div className="text-center py-10 opacity-50">
             <Search className="w-12 h-12 mx-auto mb-2 text-gray-600" />
             <p className="text-sm">No sports found.</p>
           </div>
         )}

      </div>
    </div>
  );
};

export default ActivitySelect;
