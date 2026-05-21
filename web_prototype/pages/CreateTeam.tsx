import React, { useState, useRef } from 'react';
import { ArrowLeft, Camera, Image, Check, ChevronDown, Lock, Globe } from 'lucide-react';
import { ViewState, Team } from '../types';

interface Props {
  setView: (view: ViewState) => void;
  onCreateTeam: (team: Team) => void;
}

const CreateTeam: React.FC<Props> = ({ setView, onCreateTeam }) => {
  const [name, setName] = useState('');
  const [category, setCategory] = useState('General');
  const [description, setDescription] = useState('');
  const [isPrivate, setIsPrivate] = useState(false);
  const [teamImage, setTeamImage] = useState<string>('');
  
  const fileInputRef = useRef<HTMLInputElement>(null);

  const categories = ['General', 'Skiing', 'Running', 'Fitness', 'CrossFit', 'Cycling', 'Team Sports', 'Triathlon'];

  const handleImageClick = () => {
    fileInputRef.current?.click();
  };

  const handleFileChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
        const reader = new FileReader();
        reader.onloadend = () => {
            setTeamImage(reader.result as string);
        };
        reader.readAsDataURL(file);
    }
  };

  const generateInviteCode = () => {
      // 6-character alphanumeric code
      return Math.random().toString(36).substring(2, 8).toUpperCase();
  };

  const handleCreate = () => {
    if (!name) return;

    const newTeam: Team = {
        id: Date.now().toString(),
        name,
        members: 1,
        category,
        image: teamImage,
        inviteCode: generateInviteCode(),
        description,
        isPrivate
    };

    onCreateTeam(newTeam);
  };

  return (
    <div className="min-h-screen bg-background relative flex flex-col">
       <input 
            type="file" 
            ref={fileInputRef} 
            onChange={handleFileChange} 
            accept="image/*" 
            className="hidden" 
        />

      <header className="sticky top-0 z-50 bg-background/95 backdrop-blur p-4 pb-2 border-b border-white/5 flex items-center justify-between">
        <button onClick={() => setView('teams')} className="w-10 h-10 flex items-center justify-center rounded-full hover:bg-white/10 transition">
            <ArrowLeft className="text-white" />
        </button>
        <h1 className="font-bold text-lg">Create New Team</h1>
        <div className="w-10"></div>
      </header>

      <div className="flex-1 p-6 space-y-8 overflow-y-auto pb-32">
        
        <div className="flex flex-col items-center">
            <div 
                onClick={handleImageClick}
                className="w-32 h-32 rounded-3xl bg-card border-2 border-dashed border-white/10 flex flex-col items-center justify-center cursor-pointer hover:border-secondary/50 hover:bg-white/5 transition group relative overflow-hidden"
            >
                {teamImage ? (
                    <div className="absolute inset-0 bg-cover bg-center" style={{backgroundImage: `url("${teamImage}")`}}></div>
                ) : (
                    <>
                        <div className="w-12 h-12 bg-white/5 rounded-full flex items-center justify-center mb-2 group-hover:scale-110 transition-transform">
                            <Camera className="w-6 h-6 text-gray-400" />
                        </div>
                        <span className="text-xs font-bold text-gray-500 uppercase">Logo Team</span>
                    </>
                )}
                {teamImage && (
                    <div className="absolute inset-0 bg-black/40 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity">
                        <Camera className="w-6 h-6 text-white" />
                    </div>
                )}
            </div>
        </div>

        <div className="space-y-5">
            <div className="space-y-1.5">
                <label className="text-xs font-bold text-gray-500 uppercase px-1">Team Name</label>
                <input 
                    type="text" 
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    placeholder="ex. Iron Lifters"
                    className="w-full bg-card border border-white/5 rounded-xl p-4 text-white placeholder-gray-600 focus:ring-1 focus:ring-secondary transition-all"
                />
            </div>

            <div className="space-y-1.5">
                <label className="text-xs font-bold text-gray-500 uppercase px-1">Category</label>
                <div className="relative">
                    <select 
                        value={category}
                        onChange={(e) => setCategory(e.target.value)}
                        className="w-full bg-card border border-white/5 rounded-xl p-4 text-white appearance-none focus:ring-1 focus:ring-secondary transition-all"
                    >
                        {categories.map(c => <option key={c} value={c}>{c}</option>)}
                    </select>
                    <ChevronDown className="absolute right-4 top-4 w-5 h-5 text-gray-500 pointer-events-none" />
                </div>
            </div>

            <div className="space-y-1.5">
                <label className="text-xs font-bold text-gray-500 uppercase px-1">Description <span className="text-gray-600 font-normal lowercase">(optional)</span></label>
                <textarea 
                    value={description}
                    onChange={(e) => setDescription(e.target.value)}
                    placeholder="What is this team about?"
                    className="w-full bg-card border border-white/5 rounded-xl p-4 text-white placeholder-gray-600 h-24 resize-none focus:ring-1 focus:ring-secondary transition-all"
                />
            </div>

             <div className="space-y-1.5">
                <label className="text-xs font-bold text-gray-500 uppercase px-1">Privacy</label>
                <div className="grid grid-cols-2 gap-3">
                    <button 
                        onClick={() => setIsPrivate(false)}
                        className={`p-4 rounded-xl border flex flex-col items-center gap-2 transition-all ${!isPrivate ? 'bg-secondary/10 border-secondary text-white' : 'bg-card border-white/5 text-gray-500'}`}
                    >
                        <Globe className={`w-5 h-5 ${!isPrivate ? 'text-secondary' : 'text-gray-500'}`} />
                        <span className="text-xs font-bold">Public</span>
                    </button>
                    <button 
                         onClick={() => setIsPrivate(true)}
                        className={`p-4 rounded-xl border flex flex-col items-center gap-2 transition-all ${isPrivate ? 'bg-secondary/10 border-secondary text-white' : 'bg-card border-white/5 text-gray-500'}`}
                    >
                        <Lock className={`w-5 h-5 ${isPrivate ? 'text-secondary' : 'text-gray-500'}`} />
                        <span className="text-xs font-bold">Private</span>
                    </button>
                </div>
            </div>
        </div>

      </div>

      <div className="fixed bottom-0 left-0 right-0 p-4 bg-gradient-to-t from-background via-background to-transparent z-40 pb-6 border-t border-white/5">
        <button 
            onClick={handleCreate}
            disabled={!name}
            className={`w-full py-4 rounded-full font-bold text-sm uppercase tracking-widest shadow-lg flex items-center justify-center gap-2 transition-all
                ${name ? 'bg-secondary text-white hover:bg-sky-500 active:scale-[0.98]' : 'bg-white/10 text-gray-500 cursor-not-allowed'}
            `}
        >
            <Check className="w-5 h-5" /> Create Team
        </button>
      </div>
    </div>
  );
};

export default CreateTeam;