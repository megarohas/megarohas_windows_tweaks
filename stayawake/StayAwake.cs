using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Windows.Forms;

static class Program
{
    [STAThread]
    static void Main()
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new MainForm());
    }
}

class MainForm : Form
{
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern uint SetThreadExecutionState(uint esFlags);

    const uint ES_CONTINUOUS       = 0x80000000;
    const uint ES_SYSTEM_REQUIRED  = 0x00000001;
    const uint ES_DISPLAY_REQUIRED = 0x00000002;

    readonly Timer    timer      = new Timer();
    readonly Label    lblElapsed = new Label();
    readonly Label    lblDot     = new Label();
    readonly DateTime started    = DateTime.Now;

    float scale = 1f;
    bool  dotOn = true;

    // Приложение объявлено DPI-aware, поэтому пиксельные размеры
    // масштабируем сами — иначе на 125%/150% всё съедет.
    int P(int v) { return (int)Math.Round(v * scale); }

    public MainForm()
    {
        using (var g = CreateGraphics()) scale = g.DpiX / 96f;

        AutoScaleMode   = AutoScaleMode.None;
        Text            = "Не спать";
        Icon            = LoadAppIcon();
        ClientSize      = new Size(P(400), P(190));
        FormBorderStyle = FormBorderStyle.FixedSingle;
        MaximizeBox     = false;
        StartPosition   = FormStartPosition.CenterScreen;
        BackColor       = Color.FromArgb(24, 24, 27);
        ForeColor       = Color.White;
        Font            = new Font("Segoe UI", 9F);

        int w = ClientSize.Width;

        lblDot.Text      = "●";
        lblDot.Font      = new Font("Segoe UI", 14F);
        lblDot.ForeColor = Color.FromArgb(74, 222, 128);
        lblDot.AutoSize  = false;
        lblDot.TextAlign = ContentAlignment.MiddleCenter;
        lblDot.Bounds    = new Rectangle(0, P(14), w, P(26));

        var lblTitle = new Label
        {
            Text      = "ЭКРАН НЕ ГАСНЕТ",
            Font      = new Font("Segoe UI", 15F, FontStyle.Bold),
            ForeColor = Color.FromArgb(134, 239, 172),
            AutoSize  = false,
            TextAlign = ContentAlignment.MiddleCenter,
            Bounds    = new Rectangle(0, P(44), w, P(34))
        };

        var lblInfo = new Label
        {
            Text      = "Компьютер не уснёт, пока открыто это окно.\nЗакрой его — всё вернётся к обычным настройкам.",
            ForeColor = Color.FromArgb(161, 161, 170),
            AutoSize  = false,
            TextAlign = ContentAlignment.MiddleCenter,
            Bounds    = new Rectangle(0, P(82), w, P(44))
        };

        lblElapsed.Text      = "активно 00:00:00";
        lblElapsed.ForeColor = Color.FromArgb(113, 113, 122);
        lblElapsed.AutoSize  = false;
        lblElapsed.TextAlign = ContentAlignment.MiddleCenter;
        lblElapsed.Bounds    = new Rectangle(0, P(140), w, P(22));

        Controls.AddRange(new Control[] { lblDot, lblTitle, lblInfo, lblElapsed });

        timer.Interval = 1000;
        timer.Tick    += OnTick;
        timer.Start();

        KeepAwake();
    }

    static Icon LoadAppIcon()
    {
        var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("appicon");
        return stream != null ? new Icon(stream) : null;
    }

    void KeepAwake()
    {
        SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED);
    }

    void OnTick(object sender, EventArgs e)
    {
        var up = DateTime.Now - started;
        lblElapsed.Text = string.Format("активно {0:00}:{1:00}:{2:00}",
            (int)up.TotalHours, up.Minutes, up.Seconds);

        dotOn = !dotOn;
        lblDot.ForeColor = dotOn ? Color.FromArgb(74, 222, 128) : Color.FromArgb(30, 70, 45);

        // Периодически подтверждаем запрос — на случай если система его сбросила.
        if (up.Seconds % 30 == 0) KeepAwake();
    }

    protected override void OnFormClosed(FormClosedEventArgs e)
    {
        timer.Stop();
        SetThreadExecutionState(ES_CONTINUOUS);   // снимаем блокировку
        base.OnFormClosed(e);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        using (var p = new Pen(Color.FromArgb(45, 45, 50)))
            e.Graphics.DrawLine(p, P(24), P(130), ClientSize.Width - P(24), P(130));
    }
}
