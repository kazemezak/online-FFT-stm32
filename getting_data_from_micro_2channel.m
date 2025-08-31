%% ===== تنظیمات سریال و FFT =====
port      = "COM5";        % پورت سریال؛ مطابق سیستم‌تان تغییر دهید
baudRate  = 115200;        % باید با میکرو یکی باشد
NFFT      = 512;           % همان روی میکرو
fs        = 8000;          % همان روی میکرو
bins      = NFFT/2;        % 256
hdrByte0  = hex2dec('A0'); % 0xA0
hdrByte1  = 2;             % تعداد کانال‌ها (=2)
frameLen  = 2 + NFFT;      % 514 بایت = 2 هدر + 512 بار طیف

% ===== باز کردن پورت =====
s = serialport(port, baudRate, "Timeout", 1);
s.InputBufferSize = 10 * frameLen;  % بافر کافی
flush(s);                           % پاکسازی هر دیتای مانده

% بستن ایمن پورت در پایان/خطا
cleanupObj = onCleanup(@() safeClose(s));

disp("Waiting for data...");

% ===== آماده‌سازی شکل =====
fAxis = (0:bins-1) * (fs/NFFT);      % گام فرکانس = fs/NFFT (≈15.625Hz)
figure('Name','Dual-Channel Live Spectrum (from MCU)');
tiledlayout(2,1,'TileSpacing','compact','Padding','compact');

ax1 = nexttile; grid(ax1,'on'); box(ax1,'on');
h0 = plot(ax1, fAxis, nan(1,bins), '-o');
xlabel(ax1,'Frequency (Hz)'); ylabel(ax1,'Magnitude (norm)');
title(ax1, 'Channel 0'); ylim(ax1, [0 1.05]); xlim(ax1,[0 fs/2]);

ax2 = nexttile; grid(ax2,'on'); box(ax2,'on');
h1 = plot(ax2, fAxis, nan(1,bins), '-o');
xlabel(ax2,'Frequency (Hz)'); ylabel(ax2,'Magnitude (norm)');
title(ax2, 'Channel 1'); ylim(ax2, [0 1.05]); xlim(ax2,[0 fs/2]);

% ===== حلقهٔ اصلی دریافت =====
try
    % ابتدا هم‌ترازی با هدر را پیدا کن
    syncToHeader(s, hdrByte0, hdrByte1);

    while isvalid(s)
        % صبر تا کل payload (512 بایت) برسد
        while s.NumBytesAvailable < NFFT
            pause(0.001);
            if ~isvalid(s), break; end
        end
        if ~isvalid(s), break; end

        payload = read(s, NFFT, "uint8");   % 512 بایت
        if numel(payload) ~= NFFT
            % اگر ناقص بود دوباره sync کن
            syncToHeader(s, hdrByte0, hdrByte1);
            continue;
        end

        % تفکیک کانال‌ها (هر کدام 256 بایت 0..255)
        ch0 = double(payload(1      : bins)) / 255.0;  % 0..1
        ch1 = double(payload(bins+1 : end )) / 255.0;

        % نمایش
        set(h0, 'YData', ch0);
        set(h1, 'YData', ch1);
        drawnow limitrate;

        % پس از هر فریم، دوباره هدر بعدی را چک کن (محکم‌کاری)
        if s.NumBytesAvailable < 2
            % صبر کوتاه برای رسیدن هدر بعدی
            pause(0.0005);
        end
        if s.NumBytesAvailable >= 2
            nextHdr = read(s, 2, "uint8");
            if numel(nextHdr)~=2 || nextHdr(1)~=hdrByte0 || nextHdr(2)~=hdrByte1
                % اگر هدر نبود، برگرد و دوباره سینک کن
                syncToHeader(s, hdrByte0, hdrByte1);
            end
        else
            % اگر هنوز نرسیده، در حلقهٔ بعد دوباره بررسی می‌شود
        end
    end

catch ME
    warning("Error/stopped:\n%s", getReport(ME));
end

disp("Serial port closed.");

% ===== توابع کمکی =====
function syncToHeader(s, b0, b1)
% در جریان بایت‌ها می‌گردد تا توالی [b0 b1] پیدا شود
    % ابتدا هر دیتای مانده را کم‌کم مصرف کن تا به هدر برسیم
    while isvalid(s)
        % حداقل 1 بایت لازم داریم
        while s.NumBytesAvailable < 1
            pause(0.001);
            if ~isvalid(s), return; end
        end
        b = read(s, 1, "uint8");
        if isempty(b), continue; end

        if b == b0
            % چک بایت دوم
            while s.NumBytesAvailable < 1
                pause(0.001);
                if ~isvalid(s), return; end
            end
            b2 = read(s, 1, "uint8");
            if ~isempty(b2) && b2 == b1
                % پیدا شد
                return;
            else
                % ادامهٔ جستجو؛ بایت دوم مطابق نبود
                continue;
            end
        end
        % اگر بایت اول مطابق نبود، جستجو ادامه دارد
    end
end

function safeClose(s)
% بستن ایمن پورت
    try
        if exist('s','var') && isvalid(s)
            flush(s);
            clear s;
        end
    catch
        % ignore
    end
end
