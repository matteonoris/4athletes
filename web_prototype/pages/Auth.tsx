import React, { useMemo, useRef, useState } from 'react';
import {
  ArrowRight,
  CalendarDays,
  Camera,
  Check,
  ChevronLeft,
  Image,
  Ruler,
  Scale,
  Settings,
  ShieldCheck,
  User,
  Users,
} from 'lucide-react';
import { UserProfile, UserRole } from '../types';

interface Props {
  onRegister: (profile: UserProfile) => void;
  onLogin: () => void;
}

type OnboardingStep = 'role' | 'personal' | 'physical' | 'photo' | 'permissions';
type PlatformPreview = 'android' | 'ios';
type PermissionKey =
  | 'camera'
  | 'sleep'
  | 'heartRate'
  | 'hrv'
  | 'cycle'
  | 'workouts'
  | 'bodyMetrics';

const GoogleIcon = () => (
  <svg width="22" height="22" viewBox="0 0 24 24" fill="none" aria-hidden="true">
    <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4" />
    <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853" />
    <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l3.66-2.84z" fill="#FBBC05" />
    <path d="M12 5.38c1.62 0 3.06.56 4.21 1.66l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.47 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335" />
  </svg>
);

const AppleIcon = () => (
  <svg width="22" height="22" viewBox="0 0 256 315" fill="currentColor" aria-hidden="true">
    <path d="M213.803 167.03c.442 47.847 41.733 64.184 42.193 64.374-.343.98-6.555 22.405-21.65 44.413-13.044 19.014-26.556 37.95-47.834 38.344-20.91.383-27.647-12.353-51.573-12.353-23.905 0-31.397 12.01-51.18 12.755-20.155.735-35.63-20.322-48.748-39.208-26.824-38.64-47.33-109.13-19.818-156.883 13.633-23.712 38.076-38.746 64.577-39.124 20.156-.37 39.223 13.565 51.573 13.565 12.333 0 35.807-16.793 60.154-14.332 10.19.421 38.803 4.102 57.214 31.025-1.488.924-34.195 19.957-33.84 59.728M176.388 40.573c10.887-13.212 18.25-31.55 16.242-49.827-15.688.636-34.693 10.45-45.932 23.596-10.076 11.664-18.89 30.345-16.516 48.243 17.514 1.355 35.313-8.8 46.206-22.012" />
  </svg>
);

const athleteSteps: OnboardingStep[] = ['role', 'personal', 'physical', 'photo', 'permissions'];
const coachSteps: OnboardingStep[] = ['role', 'personal', 'photo'];

const Auth: React.FC<Props> = ({ onRegister, onLogin }) => {
  const inferredPlatform: PlatformPreview =
    /iPad|iPhone|iPod/i.test(navigator.userAgent) ? 'ios' : 'android';
  const [hasStartedOnboarding, setHasStartedOnboarding] = useState(false);
  const [step, setStep] = useState<OnboardingStep>('role');
  const [role, setRole] = useState<UserRole>('athlete');
  const [firstName, setFirstName] = useState('Mario');
  const [lastName, setLastName] = useState('Rossi');
  const [birthDate, setBirthDate] = useState('1998-05-06');
  const [weight, setWeight] = useState('72');
  const [height, setHeight] = useState('178');
  const [gender, setGender] = useState<'M' | 'F'>('M');
  const [avatarUrl, setAvatarUrl] = useState('');
  const [notice, setNotice] = useState('');
  const cameraInputRef = useRef<HTMLInputElement>(null);
  const galleryInputRef = useRef<HTMLInputElement>(null);

  const platform = inferredPlatform;
  const activeSteps = role === 'coach' ? coachSteps : athleteSteps;
  const stepIndex = activeSteps.indexOf(step) + 1;

  const title = useMemo(() => {
    if (step === 'role') return 'Chi sei?';
    if (step === 'personal') return 'I tuoi dati';
    if (step === 'physical') return 'Fisico';
    if (step === 'photo') return 'Foto profilo';
    return platform === 'ios' ? 'Apple Health' : 'Health Connect';
  }, [platform, step]);

  const continueWithSocial = (provider: 'Google' | 'Apple') => {
    setNotice(`${provider} selezionato. Preview locale: nessun account reale viene creato.`);
    setHasStartedOnboarding(true);
    setStep('role');
  };

  const goBack = () => {
    setNotice('');
    const currentIndex = activeSteps.indexOf(step);
    if (currentIndex > 0) {
      setStep(activeSteps[currentIndex - 1]);
      return;
    }
    setHasStartedOnboarding(false);
  };

  const nextStep = () => {
    setNotice('');
    const currentIndex = activeSteps.indexOf(step);
    if (currentIndex < activeSteps.length - 1) {
      setStep(activeSteps[currentIndex + 1]);
      return;
    }
    finishRegistration();
  };

  const finishRegistration = () => {
    const profile: UserProfile = {
      firstName: firstName || 'Utente',
      lastName: lastName || 'Nuovo',
      email: 'preview@4athletes.local',
      birthDate: birthDate || '2000-01-01',
      role,
      weight: Number.parseFloat(weight) || 0,
      height: Number.parseFloat(height) || 0,
      maxHr: 190,
      unitSystem: 'metric',
      language: 'it',
      avatarUrl,
      notificationsEnabled: true,
      connectedDevices: [],
      oneRepMax: {},
    };

    onRegister(profile);
  };

  const handleImage = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onloadend = () => setAvatarUrl(reader.result as string);
    reader.readAsDataURL(file);
  };

  const openPlatformSettings = () => {
    setNotice(
      platform === 'ios'
        ? 'Nell\'app iOS apriremo Impostazioni > Salute > Accesso dati e dispositivi.'
        : 'Nell\'app Android apriremo Impostazioni > Health Connect > Autorizzazioni app.',
    );
  };

  if (!hasStartedOnboarding) {
    return (
      <AuthShell>
        <div className="flex min-h-[calc(100vh-32px)] flex-col justify-center">
          <div className="mb-14 text-center">
            <div className="mx-auto mb-8 flex h-28 w-28 items-center justify-center overflow-hidden rounded-[32px] bg-card shadow-2xl">
              <img src="/assets/images/logo.png" alt="4athletes" className="h-full w-full object-cover" />
            </div>
            <h1 className="text-4xl font-black tracking-[0.08em] text-white">4ATHLETES</h1>
            <p className="mt-3 text-base text-white/50">Track, Analyze, and Dominate.</p>
          </div>

          <button onClick={() => continueWithSocial('Google')} className="flex h-16 items-center justify-center gap-3 rounded-2xl bg-white text-lg font-bold text-black">
            <GoogleIcon /> Continua con Google
          </button>
          <button onClick={() => continueWithSocial('Apple')} className="mt-4 flex h-16 items-center justify-center gap-3 rounded-2xl border border-white/5 bg-card text-lg font-bold text-white">
            <AppleIcon /> Continua con Apple
          </button>
          <button onClick={onLogin} className="mt-8 text-sm font-bold text-white/45">
            Entra nel prototipo locale
          </button>
          {notice && <Notice text={notice} />}
        </div>
      </AuthShell>
    );
  }

  return (
    <AuthShell>
      <input ref={cameraInputRef} type="file" accept="image/*" capture="user" onChange={handleImage} className="hidden" />
      <input ref={galleryInputRef} type="file" accept="image/*" onChange={handleImage} className="hidden" />

      <div className="flex min-h-[calc(100vh-32px)] flex-col">
        <SignupHeader title={title} currentStep={stepIndex} totalSteps={activeSteps.length} onBack={goBack} />

        <main className="flex flex-1 flex-col">
          {step === 'role' && (
            <div className="flex flex-1 flex-col">
              <RoleCard
                selected={role === 'athlete'}
                icon={<User className="h-8 w-8" />}
                title="Atleta"
                body="Traccia i tuoi allenamenti, monitora i progressi e competi con la squadra."
                onClick={() => setRole('athlete')}
                tone="blue"
              />
              <RoleCard
                selected={role === 'coach'}
                icon={<Users className="h-8 w-8" />}
                title="Allenatore"
                body="Gestisci i tuoi team, analizza le performance e pianifica le sessioni."
                onClick={() => setRole('coach')}
                tone="green"
              />
              <PrimaryButton label="Avanti" onClick={nextStep} />
            </div>
          )}

          {step === 'personal' && (
            <FormStep>
              <div className="grid grid-cols-2 gap-4">
                <Field label="Nome" value={firstName} onChange={setFirstName} />
                <Field label="Cognome" value={lastName} onChange={setLastName} />
              </div>
              <Field
                label="Data di nascita"
                icon={<CalendarDays />}
                value={birthDate}
                onChange={setBirthDate}
                type="date"
              />
              <div>
                <span className="mb-2 block text-xs font-black uppercase tracking-[0.14em] text-white/45">Sesso</span>
                <div className="grid grid-cols-2 gap-3">
                  {(['M', 'F'] as const).map((option) => (
                    <button
                      key={option}
                      onClick={() => setGender(option)}
                      className={`h-14 rounded-2xl border text-lg font-black ${gender === option ? 'border-secondary bg-secondary text-white' : 'border-white/5 bg-card text-white/50'}`}
                    >
                      {option}
                    </button>
                  ))}
                </div>
              </div>
              <PrimaryButton label="Avanti" onClick={nextStep} />
            </FormStep>
          )}

          {step === 'physical' && (
            <FormStep>
              <p className="text-sm leading-relaxed text-white/50">Questi dati ci aiutano a personalizzare la tua esperienza. Puoi saltarli e inserirli in un secondo momento dal tuo profilo.</p>
              <div className="grid grid-cols-2 gap-4">
                <Field label="Peso (kg)" icon={<Scale />} value={weight} onChange={setWeight} inputMode="decimal" />
                <Field label="Altezza (cm)" icon={<Ruler />} value={height} onChange={setHeight} inputMode="numeric" />
              </div>
              <PrimaryButton label="Avanti" onClick={nextStep} />
              <button onClick={() => { setWeight(''); setHeight(''); nextStep(); }} className="mt-1 h-12 text-base font-bold text-white/45">
                Salta per ora
              </button>
            </FormStep>
          )}

          {step === 'photo' && (
            <FormStep>
              <div className="flex flex-col items-center pt-2">
                <button onClick={() => galleryInputRef.current?.click()} className="relative h-48 w-48 overflow-hidden rounded-[36px] border-4 border-white/5 bg-card">
                  {avatarUrl ? (
                    <img src={avatarUrl} alt="Anteprima profilo" className="h-full w-full object-cover" />
                  ) : (
                    <span className="flex h-full w-full items-center justify-center text-white/30">
                      <User className="h-20 w-20" />
                    </span>
                  )}
                  <span className="absolute bottom-3 right-3 rounded-2xl bg-secondary p-3 text-white">
                    <Image className="h-6 w-6" />
                  </span>
                </button>
              </div>
              <button onClick={() => cameraInputRef.current?.click()} className="flex h-16 items-center justify-center gap-3 rounded-2xl bg-secondary text-lg font-black text-white">
                <Camera className="h-6 w-6" /> Scatta foto
              </button>
              <button onClick={() => galleryInputRef.current?.click()} className="flex h-14 items-center justify-center gap-3 rounded-2xl bg-card text-base font-bold text-white/60">
                <Image className="h-5 w-5" /> Scegli dalla galleria
              </button>
              <PrimaryButton label={role === 'coach' ? 'Completa' : 'Avanti'} onClick={nextStep} />
              <button onClick={nextStep} className="mt-1 h-12 text-base font-bold text-white/45">
                Salta per ora
              </button>
            </FormStep>
          )}

          {step === 'permissions' && (
            <FormStep>
              <div className="rounded-[24px] border border-white/5 bg-card p-5">
                <div className="mb-5 flex items-center gap-4">
                  <span className="rounded-2xl bg-secondary/15 p-4 text-secondary">
                    <ShieldCheck className="h-7 w-7" />
                  </span>
                  <div>
                    <h2 className="text-xl font-black text-white">{platform === 'ios' ? 'Apple Health' : 'Health Connect'}</h2>
                    <p className="text-sm text-white/45">{platform === 'ios' ? 'Salute, fotocamera e dati sensibili' : 'Health Connect, fotocamera e dati sensibili'}</p>
                  </div>
                </div>
                <div className="mb-5 rounded-2xl bg-background/55 px-4 py-3 text-sm font-bold text-white/50">
                  Rilevato automaticamente: {platform === 'ios' ? 'iOS' : 'Android'}
                </div>
                <div className="space-y-3">
                  {permissionRows.map((permission) => (
                    <PermissionRow key={permission.key} permission={permission} />
                  ))}
                </div>
              </div>

              <button onClick={openPlatformSettings} className="flex h-14 items-center justify-center gap-3 rounded-2xl bg-card text-base font-bold text-white/65">
                <Settings className="h-5 w-5" /> Apri impostazioni
              </button>
              {notice && <Notice text={notice} />}
              <PrimaryButton label="Consenti e completa" onClick={finishRegistration} />
              <button onClick={finishRegistration} className="mt-1 h-12 text-base font-bold text-white/45">
                Salta per ora
              </button>
            </FormStep>
          )}
        </main>
      </div>
    </AuthShell>
  );
};

const permissionRows: Array<{ key: PermissionKey; label: string; detail: string }> = [
  { key: 'camera', label: 'Fotocamera', detail: 'Foto profilo' },
  { key: 'sleep', label: 'Sonno', detail: 'Qualità e durata' },
  { key: 'heartRate', label: 'Frequenza cardiaca', detail: 'FC, HRV e recupero' },
  { key: 'cycle', label: 'Ciclo mestruale', detail: 'Fasi e personalizzazione' },
  { key: 'workouts', label: 'Allenamenti', detail: 'Sessioni e carico' },
  { key: 'bodyMetrics', label: 'Metriche corporee', detail: 'Peso, altezza, temperatura' },
];

const AuthShell = ({ children }: { children: React.ReactNode }) => (
  <div className="min-h-screen bg-background text-white">
    <div className="pointer-events-none fixed -left-28 -top-28 h-80 w-80 rounded-full bg-secondary/15 blur-3xl" />
    <div className="pointer-events-none fixed -bottom-28 -right-28 h-80 w-80 rounded-full bg-primary/10 blur-3xl" />
    <div className="relative mx-auto min-h-screen w-full max-w-[430px] px-6 py-4 font-sans">
      {children}
    </div>
  </div>
);

const SignupHeader = ({ title, currentStep, totalSteps, onBack }: { title: string; currentStep: number; totalSteps: number; onBack: () => void }) => (
  <header className="pb-8 pt-6">
    <div className="mb-7 flex items-center justify-between">
      <button onClick={onBack} className="flex h-16 w-16 items-center justify-center rounded-full bg-card text-white">
        <ChevronLeft className="h-8 w-8" />
      </button>
      <div className="rounded-full bg-card px-6 py-3 text-lg font-black text-white/55">
        Passo {currentStep} di {totalSteps}
      </div>
    </div>
    <div className="mb-8 grid gap-3" style={{ gridTemplateColumns: `repeat(${totalSteps}, minmax(0, 1fr))` }}>
      {Array.from({ length: totalSteps }).map((_, index) => (
        <div key={index} className={`h-1.5 rounded-full ${index < currentStep ? 'bg-secondary' : 'bg-card'}`} />
      ))}
    </div>
    <p className="text-sm font-black uppercase tracking-[0.22em] text-secondary">Iscrizione</p>
    <h1 className="mt-3 text-5xl font-black leading-tight text-white">{title}</h1>
  </header>
);

const RoleCard = ({ selected, icon, title, body, onClick, tone }: { selected: boolean; icon: React.ReactNode; title: string; body: string; onClick: () => void; tone: 'blue' | 'green' }) => (
  <button onClick={onClick} className={`mb-5 rounded-[24px] border-2 bg-card p-7 text-left transition ${selected ? (tone === 'blue' ? 'border-secondary/70' : 'border-primary/70') : 'border-white/5'}`}>
    <span className={`mb-7 flex h-24 w-24 items-center justify-center rounded-[28px] ${tone === 'blue' ? 'bg-secondary/10 text-white' : 'bg-primary/10 text-white'}`}>
      {icon}
    </span>
    <h2 className="text-3xl font-black text-white">{title}</h2>
    <p className="mt-4 text-xl leading-relaxed text-white/55">{body}</p>
  </button>
);

const FormStep = ({ children }: { children: React.ReactNode }) => (
  <div className="flex flex-1 flex-col gap-6 pb-6">{children}</div>
);

const Field = ({ label, value, onChange, icon, type = 'text', inputMode }: { label: string; value: string; onChange: (value: string) => void; icon?: React.ReactNode; type?: string; inputMode?: React.HTMLAttributes<HTMLInputElement>['inputMode'] }) => (
  <label className="block">
    <span className="mb-2 block text-xs font-black uppercase tracking-[0.14em] text-white/45">{label}</span>
    <span className="relative block">
      {icon && <span className="absolute left-4 top-1/2 h-5 w-5 -translate-y-1/2 text-white/35 [&>svg]:h-5 [&>svg]:w-5">{icon}</span>}
      <input
        value={value}
        onChange={(event) => onChange(event.target.value)}
        type={type}
        inputMode={inputMode}
        className={`h-14 w-full rounded-2xl border border-white/5 bg-card text-base text-white outline-none transition focus:border-secondary ${icon ? 'pl-12 pr-4' : 'px-4'}`}
      />
    </span>
  </label>
);

const PermissionRow = ({ permission }: { permission: { label: string; detail: string } }) => (
  <div className="flex items-center justify-between gap-4 rounded-2xl bg-background/55 px-4 py-3">
    <div>
      <p className="font-bold text-white">{permission.label}</p>
      <p className="text-xs font-semibold text-white/35">{permission.detail}</p>
    </div>
    <span className="rounded-full bg-secondary/15 p-2 text-secondary">
      <Check className="h-4 w-4" />
    </span>
  </div>
);

const PrimaryButton = ({ label, onClick }: { label: string; onClick: () => void }) => (
  <button onClick={onClick} className="mt-auto flex h-16 w-full items-center justify-center gap-3 rounded-2xl bg-secondary text-lg font-black text-white shadow-2xl shadow-secondary/25 active:scale-[0.98]">
    {label} <ArrowRight className="h-5 w-5" />
  </button>
);

const Notice = ({ text }: { text: string }) => (
  <div className="mt-5 rounded-2xl border border-white/5 bg-card px-4 py-3 text-sm font-semibold leading-relaxed text-white/60">
    {text}
  </div>
);

export default Auth;
