%% تنظیمات سریال و FFT
port       = "COM5";      % پورت سریال
baudRate   = 115200;       % باید با MCU یکی باشد (تو کدت 115200 است)
NFFT       = 512;          % اندازه FFT روی MCU
fs         = 8000;         % نرخ نمونه‌برداری واقعی روی MCU (TIM2 → 8 kHz)
frameSize  = NFFT/2;       % MCU هر فریم 256 بایت می‌فرستد (بازه‌ی 0..Nyquist-1)

% سریال
serialObj = serialport(port, baudRate, "Timeout", 1);
configureCallback(serialObj, "off");                 % کالبک لازم نداریم
serialObj.InputBufferSize = 10*frameSize;           % بافر کافی

disp("Waiting for data...");

% شکل
figure('Name','Real-Time Spectrum (from MCU)');
hAx = axes; grid(hAx, 'on'); box(hAx,'on');
freqVector = (0:frameSize-1) * (fs / NFFT);         % گام فرکانسی = fs/NFFT (=15.625Hz)
hLine = plot(hAx, freqVector, nan(1,frameSize), '-o');
xlabel('Frequency (Hz)'); ylabel('Magnitude (norm)');
title(sprintf('Live Spectrum: NFFT=%d, fs=%.0f Hz', NFFT, fs));
ylim([0 1.05]); xlim([0 fs/2]);

% حلقه‌ی خواندن و رسم
try
    while isvalid(serialObj)
        % تا رسیدن به 256 بایت کامل صبر کن
        if serialObj.NumBytesAvailable < frameSize
            pause(0.001);
            continue;
        end
        rawData = read(serialObj, frameSize, "uint8");  % دقیقاً 256 بایت
        
        if numel(rawData) ~= frameSize
            % اگر ناقص شد، رد کن
            continue;
        end
        
        % داده‌های MCU همین حالا magnitude هستند (0..255). نرمال به 0..1:
        mag = double(rawData) / 255.0;
        
        % نمایش
        set(hLine, 'YData', mag);
        drawnow limitrate;
    end
catch ME
    warning("Error occurred or stopped.\n%s", getReport(ME));
end

if exist("serialObj","var") && isvalid(serialObj)
    clear serialObj;
end
disp("Serial port closed.");
