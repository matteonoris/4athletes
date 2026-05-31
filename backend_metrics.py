import math
from typing import List, Tuple
from datetime import datetime

class CalibrationPhaseError(Exception):
    """Eccezione controllata per gestire la mancanza di dati storici sufficienti (< 4 giorni)."""
    pass

class AthleteMetricsEngine:
    def __init__(self, k_sigmoid: float = 1.5):
        self.k_sigmoid = k_sigmoid

    def calculate_sleep_score(self, total_sleep_time: float, target_sleep_time: float, 
                              deep_sleep_time: float, rem_sleep_time: float, time_in_bed: float,
                              sleep_onset_time: datetime, avg_sleep_onset_time: datetime) -> float:
        """
        Calcola lo Sleep Score (0-100) basato su durata, architettura, regolarità circadiana ed efficienza.
        I parametri temporali (total_sleep_time, etc.) sono espressi in minuti.
        """
        # 1. Durata (40%)
        duration_score = min((total_sleep_time / target_sleep_time) * 100.0, 100.0)
        
        # 2. Architettura (25%)
        arch_ratio = (deep_sleep_time + rem_sleep_time) / total_sleep_time
        if arch_ratio >= 0.40:
            arch_score = 100.0
        else:
            arch_score = (arch_ratio / 0.40) * 100.0
            
        # 3. Regolarità Circadiana (20%)
        diff_minutes = abs((sleep_onset_time - avg_sleep_onset_time).total_seconds()) / 60.0
        if diff_minutes <= 30.0:
            circadian_score = 100.0
        else:
            extra_minutes = diff_minutes - 30.0
            # -15 punti per ogni 30 minuti interi extra di deviazione
            penalties = (extra_minutes // 30) * 15.0
            circadian_score = max(0.0, 100.0 - penalties)
            
        # 4. Efficienza (15%)
        efficiency_score = min((total_sleep_time / time_in_bed) * 100.0, 100.0)
        
        # Somma pesata
        total_score = (duration_score * 0.40) + (arch_score * 0.25) + (circadian_score * 0.20) + (efficiency_score * 0.15)
        return total_score

    def _get_stats(self, data: List[float], min_std: float) -> Tuple[float, float]:
        """
        Calcola Media e Deviazione Standard della finestra storica.
        Se la Deviazione Standard è 0, forza al valore `min_std` per evitare ZeroDivisionError.
        """
        mean = sum(data) / len(data)
        variance = sum((x - mean) ** 2 for x in data) / len(data)
        std = math.sqrt(variance)
        if std == 0.0:
            std = min_std
        return mean, std

    def calculate_recovery_score(self, is_luteal_phase: bool,
                                 rhr_today: float, rhr_history: List[float],
                                 temp_today: float, temp_history: List[float],
                                 hrv_today: float, hrv_history: List[float],
                                 sleep_score: float,
                                 resp_today: float, resp_history: List[float],
                                 spo2_today: float, spo2_history: List[float]) -> float:
        """
        Calcola il Recovery Score (0-100) combinando gli Z-Score normalizzati e corretti.
        Lancia CalibrationPhaseError se la storia ha < 4 giorni.
        """
        # Controllo Cold Start
        min_history = min(len(rhr_history), len(temp_history), len(hrv_history), len(resp_history), len(spo2_history))
        if min_history < 4:
            raise CalibrationPhaseError(f"CALIBRATION_PHASE: Dati storici insufficienti ({min_history} giorni su 4 minimi).")

        # Correzioni ormonali (Ciclo Mestruale)
        if is_luteal_phase:
            rhr_today -= 2.0         # Rimuove il tipico aumento fisiologico
            temp_today -= 0.4        # Rimuove l'aumento termico basale
            hrv_today *= 1.10        # Aumenta del +10% come tolleranza

        # Calcolo Statistiche Storiche (Media, DevStd)
        rhr_mean, rhr_std = self._get_stats(rhr_history, min_std=0.1)
        temp_mean, temp_std = self._get_stats(temp_history, min_std=0.1)
        resp_mean, resp_std = self._get_stats(resp_history, min_std=0.1)
        spo2_mean, spo2_std = self._get_stats(spo2_history, min_std=0.1)

        # HRV richiede Trasformazione Logaritmica
        ln_hrv_today = math.log(hrv_today)
        ln_hrv_history = [math.log(x) for x in hrv_history]
        ln_hrv_mean, ln_hrv_std = self._get_stats(ln_hrv_history, min_std=1.0)

        # --- CALCOLO Z-SCORE CON DIREZIONALITÀ ---
        
        # 1. HRV (35%) - Direzionalità Positiva
        z_hrv = (ln_hrv_today - ln_hrv_mean) / ln_hrv_std
        
        # 2. RHR (20%) - Direzionalità Inversa
        z_rhr = -((rhr_today - rhr_mean) / rhr_std)
        
        # 3. Temperatura Cutanea (15%) - Inversa SOLO SE POSITIVA (penalità su calore)
        z_temp_raw = (temp_today - temp_mean) / temp_std
        z_temp = -z_temp_raw if z_temp_raw > 0 else 0.0
        
        # 4. Sleep Score (15%) - Mappato da (0-100) a (-3 a +3)
        z_sleep = (sleep_score / 100.0 * 6.0) - 3.0
        
        # 5. Frequenza Respiratoria (10%) - Direzionalità Inversa
        z_resp = -((resp_today - resp_mean) / resp_std)
        
        # 6. SpO2 (5%) - Direzionalità positiva solo sui cali
        z_spo2_raw = (spo2_today - spo2_mean) / spo2_std
        z_spo2 = z_spo2_raw if z_spo2_raw < 0 else 0.0
        
        # --- Z-TOTALE E TRASFORMAZIONE FINALE ---
        z_totale = (z_hrv * 0.35) + (z_rhr * 0.20) + (z_temp * 0.15) + (z_sleep * 0.15) + (z_resp * 0.10) + (z_spo2 * 0.05)
        
        # Sigmoide per ottenere Score da 0 a 100
        recovery_score = 100.0 / (1.0 + math.exp(-self.k_sigmoid * z_totale))
        return recovery_score


def run_tests():
    """Script di test per validare i tre scenari richiesti."""
    engine = AthleteMetricsEngine()
    
    # Baseline comune per gli scenari
    base_rhr_history = [45.0, 46.0, 44.0, 45.0, 47.0]
    base_temp_history = [36.5, 36.6, 36.5, 36.4, 36.5]
    base_hrv_history = [90.0, 85.0, 95.0, 92.0, 88.0]
    base_resp_history = [14.0, 14.2, 13.8, 14.0, 14.1]
    base_spo2_history = [98.0, 99.0, 98.0, 97.0, 98.0]
    
    # Costruiamo uno sleep_score standard per i primi due scenari
    standard_sleep_score = engine.calculate_sleep_score(
        total_sleep_time=480, target_sleep_time=480, 
        deep_sleep_time=120, rem_sleep_time=100, time_in_bed=500,
        sleep_onset_time=datetime(2023, 1, 1, 23, 0), avg_sleep_onset_time=datetime(2023, 1, 1, 23, 10)
    )

    print("=========================================")
    print("SCENARIO 1: Atleta Ottimale")
    print("=========================================")
    # Metriche odierne eccellenti
    recovery_opt = engine.calculate_recovery_score(
        is_luteal_phase=False,
        rhr_today=43.0, rhr_history=base_rhr_history, # Più bassa del solito
        temp_today=36.4, temp_history=base_temp_history,
        hrv_today=100.0, hrv_history=base_hrv_history, # HRV alto
        sleep_score=standard_sleep_score,
        resp_today=13.5, resp_history=base_resp_history,
        spo2_today=99.0, spo2_history=base_spo2_history
    )
    print(f"Sleep Score:    {standard_sleep_score:.2f} / 100")
    print(f"Recovery Score: {recovery_opt:.2f} / 100")
    print("\n")

    print("=========================================")
    print("SCENARIO 2: Atleta Donna (Fase Luteale)")
    print("=========================================")
    # Metriche leggermente "peggiorate" ma fisiologiche per la fase luteale
    rhr_luteal = 47.0
    temp_luteal = 36.9
    hrv_luteal = 80.0
    
    # 2a. Senza Correzione (Mostra come l'algoritmo penalizzerebbe ingiustamente)
    recovery_uncorrected = engine.calculate_recovery_score(
        is_luteal_phase=False,
        rhr_today=rhr_luteal, rhr_history=base_rhr_history,
        temp_today=temp_luteal, temp_history=base_temp_history,
        hrv_today=hrv_luteal, hrv_history=base_hrv_history,
        sleep_score=standard_sleep_score,
        resp_today=14.0, resp_history=base_resp_history,
        spo2_today=98.0, spo2_history=base_spo2_history
    )
    
    # 2b. Con Correzione (Mostra il recupero reale dell'atleta considerando la biologia)
    recovery_corrected = engine.calculate_recovery_score(
        is_luteal_phase=True,
        rhr_today=rhr_luteal, rhr_history=base_rhr_history,
        temp_today=temp_luteal, temp_history=base_temp_history,
        hrv_today=hrv_luteal, hrv_history=base_hrv_history,
        sleep_score=standard_sleep_score,
        resp_today=14.0, resp_history=base_resp_history,
        spo2_today=98.0, spo2_history=base_spo2_history
    )
    print(f"Recovery Score (SENZA correzione ormonale): {recovery_uncorrected:.2f} / 100")
    print(f"Recovery Score (CON correzione ormonale):   {recovery_corrected:.2f} / 100")
    print("\n")

    print("=========================================")
    print("SCENARIO 3: Atleta con Infezione/Febbre")
    print("=========================================")
    # Sonno ridotto per febbre/sveglie
    sick_sleep_score = engine.calculate_sleep_score(
        total_sleep_time=240, target_sleep_time=480, 
        deep_sleep_time=20, rem_sleep_time=30, time_in_bed=400,
        sleep_onset_time=datetime(2023, 1, 2, 2, 0), avg_sleep_onset_time=datetime(2023, 1, 1, 23, 10)
    )
    # Metriche molto sballate
    recovery_sick = engine.calculate_recovery_score(
        is_luteal_phase=False,
        rhr_today=58.0, rhr_history=base_rhr_history, # Molto alta (Tachicardia)
        temp_today=38.3, temp_history=base_temp_history, # Febbre
        hrv_today=45.0, hrv_history=base_hrv_history, # HRV Crollato
        sleep_score=sick_sleep_score, # Sonno scarso
        resp_today=18.0, resp_history=base_resp_history, # Tachipnea
        spo2_today=95.0, spo2_history=base_spo2_history # SpO2 Bassa
    )
    print(f"Sleep Score:    {sick_sleep_score:.2f} / 100")
    print(f"Recovery Score: {recovery_sick:.2f} / 100")
    print("\n")

if __name__ == "__main__":
    run_tests()
