import React, { useState } from 'react';
import { User, Plus, Users, QrCode, X, ArrowRight, Clipboard, Loader2, CheckCircle, AlertCircle } from 'lucide-react';
import { ViewState, Language, Team } from '../types';
import { translations } from '../i18n';

interface Props {
  setView: (view: ViewState) => void;
  language: Language;
  teams?: Team[];
  onTeamClick?: (id: string) => void;
  onJoinByCode?: (code: string) => boolean;
}

const Teams: React.FC<Props> = ({ setView, language, teams = [], onTeamClick, onJoinByCode }) => {
  const t = translations[language];
  
  const [showJoinModal, setShowJoinModal] = useState(false);
  const [inviteCode, setInviteCode] = useState('');
  const [joinStatus, setJoinStatus] = useState<'idle' | 'loading' | 'success' | 'error'>('idle');

  const handleJoin = () => {
    if (inviteCode.length < 4) return;
    
    setJoinStatus('loading');
    
    // Simulate API/App logic delay
    setTimeout(() => {
        const success = onJoinByCode ? onJoinByCode(inviteCode) : false;
        if (!success) {
            setJoinStatus('error');
        } else {
            setJoinStatus('success');
            setTimeout(() => {
                setShowJoinModal(false);
                setInviteCode('');
                setJoinStatus('idle');
                setView('team-details');
            }, 1000);
        }
    }, 1200);
  };

  const handlePaste = async () => {
    try {
        const text = await navigator.clipboard.readText();
        if (text) setInviteCode(text.toUpperCase().slice(0, 8));
    } catch (err) {
        console.error('Failed to read clipboard', err);
    }
  };

  return (
    <div className="pb-24 pt-14 px-4 min-h-screen relative">
      
      {showJoinModal && (
        <div className="fixed inset-0 z-[60] flex items-center justify-center p-4">
            <div className="absolute inset-0 bg-black/80 backdrop-blur-sm" onClick={() => setShowJoinModal(false)}></div>
            <div className="bg-card w-full max-w-sm rounded-3xl border border-white/10 p-6 relative z-10 animate-in zoom-in-95 duration-200 shadow-2xl">
                
                <button 
                    onClick={() => setShowJoinModal(false)}
                    className="absolute top-4 right-4 p-2 text-gray-500 hover:text-white bg-white/5 rounded-full"
                >
                    <X className="w-5 h-5" />
                </button>

                <div className="text-center mb-6">
                    <div className="w-16 h-16 bg-gradient-to-tr from-secondary to-primary rounded-2xl mx-auto mb-4 flex items-center justify-center shadow-lg shadow-secondary/20">
                        <QrCode className="w-8 h-8 text-white" />
                    </div>
                    <h2 className="text-xl font-bold">Unisciti al Team</h2>
                    <p className="text-sm text-gray-400 mt-2 italic">Prova i codici 'ROME88' o 'MIL400'</p>
                </div>

                <div className="relative mb-6">
                    <input 
                        type="text" 
                        value={inviteCode}
                        onChange={(e) => {
                            setInviteCode(e.target.value.toUpperCase());
                            setJoinStatus('idle');
                        }}
                        placeholder="CODICE"
                        disabled={joinStatus === 'loading' || joinStatus === 'success'}
                        className={`w-full bg-surface border-2 rounded-2xl py-4 text-center text-2xl font-mono font-bold tracking-[0.2em] text-white uppercase transition-all
                            ${joinStatus === 'error' ? 'border-red-500 focus:ring-red-500' : 'border-white/10 focus:border-secondary focus:ring-secondary'}
                        `}
                    />
                    
                    {!inviteCode && (
                        <button 
                            onClick={handlePaste}
                            className="absolute right-3 top-1/2 -translate-y-1/2 p-2 text-secondary hover:bg-secondary/10 rounded-lg text-xs font-bold uppercase flex items-center gap-1"
                        >
                            <Clipboard className="w-3 h-3" /> Incolla
                        </button>
                    )}
                </div>

                {joinStatus === 'error' && (
                    <div className="flex items-center justify-center gap-2 text-red-500 text-sm font-medium mb-4 animate-in fade-in slide-in-from-top-2">
                        <AlertCircle className="w-4 h-4" />
                        <span>Codice non valido o già in uso</span>
                    </div>
                )}
                
                <button 
                    onClick={handleJoin}
                    disabled={!inviteCode || joinStatus === 'loading' || joinStatus === 'success'}
                    className={`w-full h-14 rounded-xl font-bold text-sm flex items-center justify-center gap-2 transition-all
                        ${joinStatus === 'success' 
                            ? 'bg-green-500 text-white' 
                            : 'bg-white text-black hover:bg-gray-200 disabled:opacity-50 disabled:cursor-not-allowed'}
                    `}
                >
                    {joinStatus === 'loading' ? (
                        <Loader2 className="w-5 h-5 animate-spin" />
                    ) : joinStatus === 'success' ? (
                        <>
                            <CheckCircle className="w-5 h-5" /> Benvenuto!
                        </>
                    ) : (
                        <>
                            Unisciti <ArrowRight className="w-4 h-4" />
                        </>
                    )}
                </button>
            </div>
        </div>
      )}

      <header className="fixed top-0 left-0 right-0 bg-background/95 backdrop-blur z-10 px-4 py-4 flex justify-between items-end border-b border-white/5">
        <h1 className="text-2xl font-extrabold">{t.myTeams}</h1>
        <button className="w-10 h-10 rounded-full bg-white/5 flex items-center justify-center hover:bg-white/10 transition">
            <User className="w-5 h-5 text-gray-400" />
        </button>
      </header>

      <div className="mt-6 space-y-4">
        {teams.map((team) => (
            <div key={team.id} onClick={() => onTeamClick && onTeamClick(team.id)} className="bg-card border border-white/5 p-4 rounded-xl flex items-center gap-4 cursor-pointer active:scale-95 transition-transform group">
                {team.image ? (
                    <div className="w-14 h-14 rounded-lg bg-gray-800 bg-cover bg-center border border-white/10" 
                        style={{backgroundImage: `url("${team.image}")`}}></div>
                ) : (
                    <div className="w-14 h-14 rounded-lg bg-white/5 flex items-center justify-center border border-white/10">
                        <Users className="text-gray-500" />
                    </div>
                )}
                <div className="flex-1">
                    <h3 className="font-bold text-base group-hover:text-secondary transition-colors">{team.name}</h3>
                    <p className="text-xs text-gray-400 mt-1">{team.members} Members • {team.category}</p>
                </div>
                <div className="bg-secondary/10 px-2 py-1 rounded text-[10px] font-mono font-bold text-secondary border border-secondary/20">
                    {team.inviteCode}
                </div>
            </div>
        ))}
        
        {teams.length === 0 && (
             <div className="text-center py-10 opacity-50">
                <Users className="w-12 h-12 mx-auto mb-2 text-gray-600" />
                <p className="text-sm">Non sei ancora in nessun team.</p>
             </div>
        )}

        <div 
            onClick={() => setShowJoinModal(true)}
            className="border-2 border-dashed border-white/10 rounded-xl p-6 flex flex-col items-center justify-center text-center mt-8 cursor-pointer hover:border-secondary/50 hover:bg-white/5 transition-all group"
        >
            <div className="w-12 h-12 rounded-full bg-secondary/10 flex items-center justify-center mb-3 group-hover:scale-110 transition-transform">
                <QrCode className="text-secondary w-6 h-6" />
            </div>
            <h4 className="font-bold text-sm">Hai un codice invito?</h4>
            <p className="text-xs text-gray-500 mt-1 max-w-[200px]">Unisciti immediatamente ad un team usando un codice o un link.</p>
            <span className="text-secondary text-xs font-bold uppercase mt-3 flex items-center gap-1">
                Inserisci Codice <ArrowRight className="w-3 h-3" />
            </span>
        </div>
      </div>

      <button 
        onClick={() => setView('create-team')}
        className="fixed bottom-24 right-4 bg-white text-black pl-5 pr-6 h-14 rounded-full flex items-center gap-2 shadow-lg shadow-white/10 hover:scale-105 transition-transform active:scale-95 z-20"
      >
         <Plus className="w-6 h-6" />
         <span className="font-bold text-sm uppercase tracking-wide">{t.createTeam}</span>
      </button>
    </div>
  );
};

export default Teams;