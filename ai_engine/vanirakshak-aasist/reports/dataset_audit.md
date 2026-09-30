# Dataset Audit Report (Phase 2)

## IndicVoices
Successfully connected to **dianavdavidson/indic_voices_hindi_only_random_sample_17274_2308_seed_42_clean**
### Features:
- **audio_filepath**: Audio(sampling_rate=None, decode=True, num_channels=None, stream_index=None)
- **text**: Value('string')
- **duration**: Value('float64')
- **lang**: Value('string')
- **samples**: Value('int64')
- **verbatim**: Value('string')
- **normalized**: Value('string')
- **speaker_id**: Value('string')
- **scenario**: Value('string')
- **task_name**: Value('string')
- **gender**: Value('string')
- **age_group**: Value('string')
- **job_type**: Value('string')
- **qualification**: Value('string')
- **area**: Value('string')
- **district**: Value('string')
- **state**: Value('string')
- **occupation**: Value('string')
- **verification_report**: Value('string')
- **unsanitized_verbatim**: Value('string')
- **unsanitized_normalized**: Value('string')
- **unsanitized_no_noise_inds**: Value('string')
- **audio_with_noise**: Value('int64')
- **unsanitized_no_noise_inds_merged_acronyms**: Value('string')
- **no_noise_inds_merged_acronyms**: Value('string')
- **sanitized_no_latin**: Value('string')
- **english_words**: Value('string')
- **count_english_words**: Value('int64')
- **count_hindi_words**: Value('int64')
- **hinglish_mixed_scripts**: Value('string')
- **hinglish_mixed_script_lowercase**: Value('string')
- **ratio_hindi_words**: Value('float64')
- **ratio_english_words**: Value('float64')
- **ratio_english_words_range**: Value('string')
- **hindi_words**: Value('string')

### Splits:
- **train**: 17274 examples
- **validation**: 2308 examples

## IndicSynth (Hindi)
Successfully connected to **ksmashhero/IndicSynth** (Hindi)
### Features:
- **audio**: Audio(sampling_rate=None, decode=True, num_channels=None, stream_index=None)
- **Generative Model**: Value('string')
- **Source Speaker_ID**: Value('float64')
- **Target Speaker ID**: Value('int64')
- **Gender**: Value('string')
- **Source Reference Audio**: Value('string')
- **Target Reference Audio**: Value('string')
- **TTS Transcript**: Value('string')

### Splits:
- **train**: 205938 examples