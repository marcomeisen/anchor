# Coding-Prompt: Anker — iOS / iPadOS / macOS App

Kopiere diesen gesamten Prompt in Claude Code (oder ein vergleichbares Coding-Tool) als Ausgangspunkt für die Implementierung. Das eingebettete HTML-Dokument in Abschnitt 2 ist die **verbindliche visuelle Referenz** — nicht nur Inspiration. Farben, Abstände, Radien und Komponenten daraus sind final und sollen 1:1 in SwiftUI übersetzt werden, nicht neu interpretiert.

---

## 1. Rolle & Auftrag

Du bist ein erfahrener Apple-Platform-Engineer (SwiftUI, SwiftData, CloudKit, WidgetKit, App Intents, watchOS). Baue die App **„Anker"** als natives, plattformübergreifendes SwiftUI-Projekt für iOS 17+, iPadOS 17+, macOS 14+ und optional watchOS 10+ (ein Xcode-Projekt, mehrere Targets, gemeinsames Swift-Package für Datenmodell/Logik).

**Kernthese der App:** Jede Tagesaufgabe kann optional an eines von maximal vier Wochenzielen „verankert" werden. Der Fortschritt eines Ziels berechnet sich automatisch aus dem Erledigungsstatus seiner verankerten Aufgaben. Alles andere in der App ist diesem Prinzip untergeordnet — baue keine zusätzlichen Projektmanagement-Features, die davon ablenken.

Arbeite iterativ: (1) Datenmodell & Persistenz, (2) Navigationsgerüst, (3) Screen für Screen exakt nach der HTML-Referenz, (4) Widgets/Watch zuletzt. Bestätige nach jedem Block kurz, was fertig ist, bevor du weitermachst.

---

## 2. Verbindliche Design-Referenz (HTML)

Das folgende HTML/CSS-Dokument definiert alle Screens statisch (kein echtes SwiftUI, nur Design-Wahrheit). Übersetze **jede Komponente** darin in eine wiederverwendbare SwiftUI-View. Wo iOS/macOS HIG-Verhalten (z. B. Swipe-Gesten, Kontextmenüs, native Sheets) von der starren HTML-Darstellung abweichen muss, priorisiere natives Verhalten — aber Farben, Typografie-Hierarchie, Radien und Abstände bleiben verbindlich.

```html
<!DOCTYPE html>
<html lang="de">
<head>
<meta charset="UTF-8">
<title>Anker — App-Designs</title>
<style>
  :root{
    --indigo:#5B6EE8;
    --indigo-dark:#3F4FBF;
    --brass:#C9974B;
    --ink:#1C1E27;
    --paper:#F7F7FA;
    --card:#FFFFFF;
    --line:#E4E5EA;
    --line-soft:#EDEEF2;
    --muted:#8A8D98;
    --success:#34C759;
    --stage:#101116;
    --stage-2:#17181F;

    --jan:#8FA8E8; --feb:#7FCDA8; --mar:#B9D97A; --apr:#F0C955;
    --mai:#F0A968; --jun:#F09EA9; --jul:#C79BE8; --aug:#A79BE8;
    --sep:#7FB4E8; --okt:#6FD6C4; --nov:#AEB0BA; --dez:#E8B98A;

    --font-ui: -apple-system, "SF Pro Text", "SF Pro Display", "Helvetica Neue", Arial, sans-serif;
    --font-mono: ui-monospace, "SF Mono", Menlo, monospace;
  }

  * { box-sizing: border-box; }
  html,body{ margin:0; padding:0; }
  body{
    background: radial-gradient(1200px 800px at 20% -10%, #1B1D28 0%, var(--stage) 55%, #0B0C10 100%);
    font-family: var(--font-ui);
    color: var(--ink);
    padding: 56px 32px 90px;
  }

  .page-head{
    max-width: 1180px;
    margin: 0 auto 48px;
    color: #EDEEF4;
  }
  .eyebrow{
    font-family: var(--font-mono);
    font-size: 12px;
    letter-spacing: .12em;
    text-transform: uppercase;
    color: var(--brass);
    margin-bottom: 10px;
  }
  .page-head h1{
    font-size: 38px;
    line-height: 1.15;
    margin: 0 0 12px;
    font-weight: 700;
    letter-spacing: -0.01em;
  }
  .page-head p{
    max-width: 620px;
    color: #B7B9C6;
    font-size: 15px;
    line-height: 1.6;
    margin: 0;
  }

  .gallery{
    max-width: 1180px;
    margin: 0 auto;
    display: flex;
    flex-wrap: wrap;
    gap: 40px;
    align-items: flex-start;
  }

  .frame-block{ display:flex; flex-direction:column; align-items:center; gap:18px; }
  .frame-caption{ max-width: 300px; text-align:center; }
  .frame-caption .cap-title{ color:#F1F2F7; font-weight:600; font-size:14px; margin-bottom:4px; }
  .frame-caption .cap-body{ color:#9598A6; font-size:12.5px; line-height:1.5; }

  /* ---------- iPhone frame ---------- */
  .iphone{
    width: 356px;
    height: 726px;
    background: #0B0C10;
    border-radius: 54px;
    padding: 14px;
    box-shadow: 0 40px 80px -20px rgba(0,0,0,.7), inset 0 0 0 1.5px #2A2C36;
  }
  .iphone-screen{
    position:relative;
    width:100%; height:100%;
    background: var(--paper);
    border-radius: 40px;
    overflow:hidden;
    display:flex; flex-direction:column;
  }
  .dynamic-island{
    position:absolute; top:14px; left:50%; transform:translateX(-50%);
    width:100px; height:28px; background:#0B0C10; border-radius:20px; z-index:5;
  }
  .status-row{
    display:flex; justify-content:space-between; align-items:center;
    padding: 16px 26px 4px; font-size:13px; font-weight:600; color:var(--ink);
  }
  .nav-title{
    padding: 6px 20px 10px;
  }
  .nav-title .date{ font-family: var(--font-mono); font-size:11.5px; color:var(--muted); letter-spacing:.03em; }
  .nav-title h2{ margin:2px 0 0; font-size:22px; font-weight:700; }

  .week-strip{
    display:flex; justify-content:space-between;
    padding: 6px 20px 14px;
  }
  .week-dot-wrap{ display:flex; flex-direction:column; align-items:center; gap:6px; }
  .week-dot-wrap .wd{ font-size:9.5px; color:var(--muted); font-weight:600; }
  .week-dot{
    width:28px; height:28px; border-radius:50%;
    display:flex; align-items:center; justify-content:center;
    font-size:11px; font-weight:600; color:var(--ink);
    background: var(--line-soft);
  }
  .week-dot.active{ background: var(--jan); color:#1C1E27; box-shadow: 0 0 0 2px var(--card), 0 0 0 3.5px var(--jan); }
  .week-dot.has-goal::after{
    content:""; width:4px; height:4px; border-radius:50%; background:var(--brass);
    position:relative; top:11px;
  }

  .goal-banner{
    margin: 0 20px 14px;
    background: linear-gradient(135deg, #EEF0FF, #F7F1E4);
    border: 1px solid #DCE1FA;
    border-radius: 14px;
    padding: 11px 13px;
    display:flex; align-items:center; gap:10px;
  }
  .anchor-badge{
    width:26px; height:26px; border-radius:8px;
    background: var(--indigo); flex:0 0 auto;
    display:flex; align-items:center; justify-content:center;
  }
  .goal-banner .txt .lbl{ font-size:9.5px; letter-spacing:.06em; text-transform:uppercase; color:var(--indigo-dark); font-weight:700; }
  .goal-banner .txt .val{ font-size:12.5px; color:var(--ink); font-weight:600; margin-top:1px; }

  .scroll-area{ flex:1; overflow:hidden; padding: 0 20px 20px; }
  .section-label{
    font-size:11px; font-weight:700; letter-spacing:.05em; text-transform:uppercase;
    color:var(--muted); margin: 14px 0 8px;
  }

  .time-row{ display:flex; gap:10px; padding: 7px 0; border-bottom:1px solid var(--line-soft); align-items:center; }
  .time-row .t{ font-family:var(--font-mono); font-size:11px; color:var(--muted); width:38px; flex:0 0 auto; }
  .time-row .block{
    flex:1; background: var(--card); border:1px solid var(--line); border-radius:9px;
    padding: 7px 10px; font-size:12.5px; font-weight:500; color:var(--ink);
    display:flex; justify-content:space-between; align-items:center;
  }
  .time-row .block .goal-dot{ width:7px; height:7px; border-radius:50%; background:var(--indigo); }

  .task-card{
    display:flex; align-items:flex-start; gap:9px;
    background: var(--card); border:1px solid var(--line); border-radius:11px;
    padding: 10px 11px; margin-bottom:8px;
  }
  .prio-tag{
    font-size:9px; font-weight:800; color:#fff; border-radius:5px; padding:2px 5px; letter-spacing:.03em;
    flex:0 0 auto; margin-top:1px;
  }
  .prio-a{ background:#E0574D; } .prio-b{ background:var(--indigo);} .prio-c{ background:#8A8D98; }
  .task-check{
    width:17px; height:17px; border-radius:5px; border:1.6px solid var(--line); flex:0 0 auto; margin-top:1px;
  }
  .task-body .title{ font-size:13px; font-weight:600; color:var(--ink); }
  .task-body .goal-ref{
    display:inline-flex; align-items:center; gap:4px; margin-top:4px;
    font-size:10px; color:var(--indigo-dark); font-weight:600;
  }
  .task-body .goal-ref svg{ width:10px; height:10px; }

  .fab{
    position:absolute; right:22px; bottom:26px; width:52px; height:52px; border-radius:50%;
    background: var(--indigo); box-shadow: 0 10px 24px -6px rgba(91,110,232,.6);
    display:flex; align-items:center; justify-content:center;
  }

  /* ---------- Mac / iPad window ---------- */
  .mac-window{
    width: 720px;
    border-radius: 14px;
    overflow:hidden;
    background: var(--paper);
    box-shadow: 0 50px 90px -30px rgba(0,0,0,.65), 0 0 0 1px #2A2C36;
  }
  .titlebar{
    height:38px; background:#EDEEF3; display:flex; align-items:center; gap:8px; padding:0 14px;
    border-bottom:1px solid var(--line);
  }
  .traffic{ width:11px; height:11px; border-radius:50%; }
  .t-red{background:#FF5F57;} .t-yellow{background:#FEBC2E;} .t-green{background:#28C840;}
  .titlebar .wtitle{ margin-left:8px; font-size:12px; color:#6C6F7C; font-weight:600; }

  .mac-body{ display:flex; height: 470px; }
  .sidebar{
    width: 210px; background:#EFEFF4; border-right:1px solid var(--line);
    padding: 14px 10px; overflow:hidden;
  }
  .sb-search{
    background:#fff; border:1px solid var(--line); border-radius:7px; padding:6px 9px;
    font-size:11.5px; color:var(--muted); margin-bottom:14px;
  }
  .sb-year{ font-size:11px; font-weight:700; color:var(--muted); text-transform:uppercase; letter-spacing:.04em; padding:4px 6px; }
  .sb-month{
    display:flex; align-items:center; gap:8px; padding:6px 8px; border-radius:6px; font-size:12.5px; color:var(--ink);
  }
  .sb-month.open{ background:#E2E5F7; font-weight:700; }
  .sb-dot{ width:8px; height:8px; border-radius:50%; flex:0 0 auto; }
  .sb-week{ padding: 4px 8px 4px 30px; font-size:11.5px; color:#55586A; }
  .sb-week.active{ background:var(--indigo); color:#fff; border-radius:6px; font-weight:600; }
  .sb-day{ padding: 3px 8px 3px 44px; font-size:11px; color:#7A7D8A; }
  .sb-day.active{ color:var(--indigo-dark); font-weight:700; }

  .main-pane{ flex:1; display:flex; flex-direction:column; overflow:hidden; }
  .context-bar{
    display:flex; align-items:center; gap:8px; padding:10px 18px; border-bottom:1px solid var(--line); background:#fff;
  }
  .chip-btn{
    font-size:11px; font-weight:600; color:var(--indigo-dark); background:#EEF0FF; border:1px solid #DDE1FA;
    border-radius:7px; padding:5px 10px;
  }
  .chip-btn.ghost{ color:var(--muted); background:#F4F4F7; border-color:var(--line); }
  .context-bar .spacer{ flex:1; }
  .context-bar .kw{ font-family:var(--font-mono); font-size:11px; color:var(--muted); }

  .goals-row{
    display:flex; gap:10px; padding: 14px 18px; border-bottom:1px solid var(--line); background:#FBFBFD;
  }
  .goal-pill{
    flex:1; background:#fff; border:1px solid var(--line); border-radius:12px; padding:10px 12px;
    display:flex; flex-direction:column; gap:6px;
  }
  .goal-pill .gp-top{ display:flex; justify-content:space-between; align-items:center; }
  .goal-pill .gp-title{ font-size:12px; font-weight:700; color:var(--ink); }
  .ring{ width:22px; height:22px; border-radius:50%; flex:0 0 auto; }
  .progress-bar{ height:5px; border-radius:4px; background:var(--line-soft); overflow:hidden; }
  .progress-bar span{ display:block; height:100%; background:var(--indigo); }

  .week-grid{ flex:1; overflow:hidden; padding: 12px 18px; }
  .wg-row{
    display:grid; grid-template-columns: 96px 1fr; gap:12px; padding:9px 0; border-bottom:1px solid var(--line-soft); align-items:center;
  }
  .wg-row .dayname{ font-size:12.5px; font-weight:700; color:var(--ink); }
  .wg-row .daydate{ font-size:10.5px; color:var(--muted); font-family:var(--font-mono); }
  .wg-tasks{ display:flex; gap:6px; flex-wrap:wrap; }
  .mini-task{
    font-size:10.5px; background:#fff; border:1px solid var(--line); border-radius:6px; padding:4px 8px;
    display:flex; align-items:center; gap:5px; color:#3A3D4A;
  }
  .mini-task .dot{ width:6px; height:6px; border-radius:50%; }
  .wg-row.today{ background: #F3F4FF; margin: 0 -18px; padding-left:18px; padding-right:18px; border-radius:8px; }

  /* ---------- Menu bar popover ---------- */
  .menubar-mock{
    width: 300px;
  }
  .mb-bar{
    height:26px; background:#1A1B20; border-radius: 8px 8px 0 0; display:flex; align-items:center; justify-content:flex-end;
    padding: 0 10px; gap:14px;
  }
  .mb-bar .mb-icon{ width:14px; height:14px; border-radius:3px; background:#3A3C46; }
  .mb-bar .mb-icon.active{ background: var(--brass); }
  .popover{
    background:#fff; border-radius: 0 0 14px 14px; box-shadow: 0 30px 60px -18px rgba(0,0,0,.55);
    padding: 16px 16px 14px;
  }
  .popover h4{ margin:0 0 10px; font-size:13px; font-weight:700; color:var(--ink); }
  .pop-input{
    width:100%; border:1px solid var(--line); border-radius:8px; padding:9px 10px; font-size:12.5px; color:var(--ink);
    margin-bottom:10px; background:#FAFAFC;
  }
  .pop-row-label{ font-size:10.5px; font-weight:700; color:var(--muted); text-transform:uppercase; letter-spacing:.04em; margin: 8px 0 6px;}
  .pop-chips{ display:flex; gap:6px; flex-wrap:wrap; margin-bottom:10px; }
  .pop-chip{ font-size:11px; padding:5px 9px; border-radius:7px; border:1px solid var(--line); color:#4A4D5A; }
  .pop-chip.sel{ background:var(--indigo); color:#fff; border-color:var(--indigo); }
  .pop-actions{ display:flex; justify-content:flex-end; gap:8px; margin-top:12px; }
  .btn{ font-size:12px; font-weight:600; padding:7px 14px; border-radius:8px; }
  .btn.primary{ background:var(--indigo); color:#fff; }
  .btn.secondary{ background:#F0F0F3; color:#4A4D5A; }

  .anchor-icon{ width:14px; height:14px; fill:none; stroke:#fff; stroke-width:1.8; }

  /* ---------- Jahresübersicht (Mac) ---------- */
  .year-toolbar{ display:flex; align-items:center; gap:8px; padding:10px 18px; border-bottom:1px solid var(--line); background:#fff; }
  .year-toolbar h3{ margin:0; font-size:14px; font-weight:700; }
  .month-tile-grid{
    flex:1; padding:16px 18px; display:grid; grid-template-columns:repeat(4,1fr); gap:10px; overflow:hidden;
  }
  .month-tile{
    border-radius:12px; padding:12px; display:flex; flex-direction:column; justify-content:space-between; min-height:78px;
    border:1px solid rgba(0,0,0,.06);
  }
  .month-tile .mt-name{ font-size:12.5px; font-weight:700; color:#24262F; }
  .month-tile .mt-stat{ font-size:10px; color:#4A4D5A; font-weight:600; }
  .month-tile.now{ box-shadow: 0 0 0 2px var(--indigo) inset; }

  /* ---------- Ziel-Detail ---------- */
  .detail-head{ display:flex; align-items:center; gap:16px; padding:20px 20px 14px; border-bottom:1px solid var(--line); }
  .detail-ring-big{ width:64px; height:64px; flex:0 0 auto; }
  .detail-head h3{ margin:0 0 4px; font-size:17px; }
  .detail-head .sub{ font-size:11.5px; color:var(--muted); }
  .detail-stats{ display:flex; gap:22px; padding:14px 20px; border-bottom:1px solid var(--line-soft); }
  .dstat b{ display:block; font-size:17px; color:var(--ink); }
  .dstat span{ font-size:10px; color:var(--muted); text-transform:uppercase; letter-spacing:.04em; font-weight:700; }
  .detail-timeline{ display:flex; gap:6px; padding:14px 20px 0; }
  .tl-day{ flex:1; text-align:center; }
  .tl-day .tld-lbl{ font-size:9.5px; color:var(--muted); margin-bottom:5px; }
  .tl-bar{ height:44px; border-radius:6px; background:var(--line-soft); display:flex; align-items:flex-end; overflow:hidden; }
  .tl-bar span{ display:block; width:100%; background:var(--indigo); }
  .detail-tasklist{ padding:14px 20px 20px; overflow:hidden; }
  .dt-day-label{ font-size:10.5px; font-weight:700; color:var(--muted); text-transform:uppercase; margin:12px 0 6px; }
  .dt-row{ display:flex; align-items:center; gap:9px; padding:6px 0; font-size:12.5px; color:var(--ink); border-bottom:1px solid var(--line-soft); }
  .dt-row .dt-check{ width:15px; height:15px; border-radius:4px; border:1.5px solid var(--line); flex:0 0 auto; }
  .dt-row .dt-check.done{ background:var(--success); border-color:var(--success); position:relative; }
  .dt-row.muted{ color:var(--muted); text-decoration:line-through; }

  /* ---------- Onboarding ---------- */
  .onboard-wrap{ flex:1; display:flex; flex-direction:column; align-items:center; justify-content:center; padding:0 32px; text-align:center; }
  .onboard-icon{
    width:78px; height:78px; border-radius:22px; background:linear-gradient(150deg,var(--indigo),var(--indigo-dark));
    display:flex; align-items:center; justify-content:center; margin-bottom:26px;
    box-shadow:0 16px 30px -10px rgba(91,110,232,.55);
  }
  .onboard-wrap h2{ font-size:21px; margin:0 0 10px; }
  .onboard-wrap p{ font-size:13px; color:#5A5D6A; line-height:1.55; margin:0 0 30px; }
  .onboard-dots{ display:flex; gap:6px; margin-bottom:22px; }
  .onboard-dots span{ width:6px; height:6px; border-radius:50%; background:var(--line); }
  .onboard-dots span.active{ background:var(--indigo); width:16px; border-radius:3px; }
  .onboard-btn{
    width:100%; background:var(--indigo); color:#fff; border-radius:13px; padding:13px; font-size:14px; font-weight:700; text-align:center;
  }

  /* ---------- Widgets ---------- */
  .wallpaper{
    width:340px; height:340px; border-radius:34px; overflow:hidden; position:relative;
    background: linear-gradient(160deg,#4A5AC7,#2E3670 60%, #1B2050);
    padding:26px; display:flex; flex-direction:column; gap:16px;
  }
  .widget-medium{
    background:rgba(255,255,255,.14); backdrop-filter:blur(6px); border-radius:20px; padding:14px 16px;
    border:1px solid rgba(255,255,255,.18);
  }
  .widget-medium .wlbl{ font-size:9.5px; letter-spacing:.05em; text-transform:uppercase; color:rgba(255,255,255,.75); font-weight:700; margin-bottom:6px; }
  .widget-medium .wgoal{ font-size:13px; font-weight:700; color:#fff; margin-bottom:10px; }
  .widget-medium .wtask{ display:flex; align-items:center; gap:7px; font-size:11.5px; color:#fff; padding:3px 0; }
  .widget-medium .wtask .wc{ width:12px; height:12px; border-radius:4px; border:1.4px solid rgba(255,255,255,.7); }
  .lockrow{ display:flex; gap:14px; align-items:center; }
  .widget-lock{
    width:58px; height:58px; border-radius:50%; background:rgba(255,255,255,.16); border:1px solid rgba(255,255,255,.25);
    display:flex; align-items:center; justify-content:center; position:relative;
  }
  .widget-lock svg{ position:absolute; inset:0; }
  .widget-lock .wl-txt{ font-size:12px; font-weight:800; color:#fff; }
  .lock-caption{ font-size:11px; color:rgba(255,255,255,.8); }

  /* ---------- Apple Watch ---------- */
  .watch{
    width:198px; height:242px; background:#0B0C10; border-radius:52px; padding:9px;
    box-shadow:0 30px 60px -18px rgba(0,0,0,.7), inset 0 0 0 1.5px #2A2C36;
  }
  .watch-screen{
    width:100%; height:100%; background:#000; border-radius:42px; padding:16px 14px; color:#fff;
    display:flex; flex-direction:column; gap:8px;
  }
  .watch-time{ font-size:11px; color:#8A8D98; text-align:center; margin-bottom:2px; }
  .watch-ring-row{ display:flex; justify-content:center; margin-bottom:4px; }
  .watch-title{ font-size:12px; font-weight:700; text-align:center; margin-bottom:2px; }
  .watch-sub{ font-size:9.5px; color:#8A8D98; text-align:center; margin-bottom:6px; }
  .watch-task{ display:flex; align-items:center; gap:6px; font-size:10.5px; padding:3px 0; border-bottom:1px solid #202127; }
  .watch-task .wc2{ width:11px; height:11px; border-radius:3px; border:1.3px solid #5A5D6A; flex:0 0 auto; }
  .watch-task .wc2.done{ background:var(--success); border-color:var(--success); }

</style>
</head>
<body>

  <div class="page-head">
    <div class="eyebrow">Produktkonzept · Designentwurf</div>
    <h1>Anker — drei Screens, ein Prinzip</h1>
    <p>Jede Tagesaufgabe bleibt sichtbar an ihr Wochenziel „angehängt". Die drei Mockups zeigen dasselbe
       Navigationskonzept aus der Papier-Vorlage (Index · Woche · Tag) als native iOS-, iPadOS/macOS- und
       Menüleisten-Oberfläche.</p>
  </div>

  <div class="gallery">

    <!-- ================= iPHONE ================= -->
    <div class="frame-block">
      <div class="iphone">
        <div class="iphone-screen">
          <div class="dynamic-island"></div>
          <div class="status-row">
            <span>9:41</span>
            <span>●●● 5G 87%</span>
          </div>
          <div class="nav-title">
            <div class="date">DONNERSTAG · 01.01.2026 · KW 01</div>
            <h2>Heute</h2>
          </div>

          <div class="week-strip">
            <div class="week-dot-wrap"><span class="wd">Mo</span><div class="week-dot has-goal">29</div></div>
            <div class="week-dot-wrap"><span class="wd">Di</span><div class="week-dot has-goal">30</div></div>
            <div class="week-dot-wrap"><span class="wd">Mi</span><div class="week-dot">31</div></div>
            <div class="week-dot-wrap"><span class="wd">Do</span><div class="week-dot active has-goal">01</div></div>
            <div class="week-dot-wrap"><span class="wd">Fr</span><div class="week-dot">02</div></div>
            <div class="week-dot-wrap"><span class="wd">Sa</span><div class="week-dot">03</div></div>
            <div class="week-dot-wrap"><span class="wd">So</span><div class="week-dot">04</div></div>
          </div>

          <div class="goal-banner">
            <div class="anchor-badge">
              <svg class="anchor-icon" viewBox="0 0 24 24"><path d="M12 3v14M8 7a4 4 0 0 0 8 0M5 13a7 7 0 0 0 14 0M12 21c-2 0-3.5-1-3.5-1"/><circle cx="12" cy="4.2" r="1.4" fill="#fff" stroke="none"/></svg>
            </div>
            <div class="txt">
              <div class="lbl">Verankert an Wochenziel</div>
              <div class="val">Jahresplanung 2026 abschließen</div>
            </div>
          </div>

          <div class="scroll-area">
            <div class="section-label">Zeitplan</div>
            <div class="time-row"><span class="t">09:00</span><div class="block">Team-Sync Produkt <span class="goal-dot"></span></div></div>
            <div class="time-row"><span class="t">11:00</span><div class="block">Konzeptreview mit Team</div></div>

            <div class="section-label">Prio A</div>
            <div class="task-card">
              <span class="prio-tag prio-a">A</span>
              <div class="task-check"></div>
              <div class="task-body">
                <div class="title">Executive Summary finalisieren</div>
                <div class="goal-ref">
                  <svg viewBox="0 0 24 24" stroke="#3F4FBF" fill="none" stroke-width="2"><path d="M12 3v14M8 7a4 4 0 0 0 8 0M5 13a7 7 0 0 0 14 0"/></svg>
                  Jahresplanung 2026
                </div>
              </div>
            </div>
            <div class="task-card">
              <span class="prio-tag prio-b">B</span>
              <div class="task-check"></div>
              <div class="task-body">
                <div class="title">Rückmeldung an R+V senden</div>
              </div>
            </div>
          </div>
          <div class="fab">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.4" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>
          </div>
        </div>
      </div>
      <div class="frame-caption">
        <div class="cap-title">iPhone — „Heute"</div>
        <div class="cap-body">Wochenstreifen statt Tab-Leiste, Zielbanner ersetzt die blaue Box aus der
          Papier-Vorlage, jede Aufgabe zeigt ihren Anker-Bezug direkt inline.</div>
      </div>
    </div>

    <!-- ================= iPAD / MAC ================= -->
    <div class="frame-block">
      <div class="mac-window">
        <div class="titlebar">
          <span class="traffic t-red"></span><span class="traffic t-yellow"></span><span class="traffic t-green"></span>
          <span class="wtitle">Anker — Wochenübersicht</span>
        </div>
        <div class="mac-body">
          <div class="sidebar">
            <div class="sb-search">⌕ Ziele, Aufgaben, Notizen</div>
            <div class="sb-year">2026</div>
            <div class="sb-month open"><span class="sb-dot" style="background:var(--jan)"></span>Januar</div>
            <div class="sb-week active">Woche 01</div>
            <div class="sb-day">Do 01.01.</div>
            <div class="sb-day active">Fr 02.01.</div>
            <div class="sb-day">Sa 03.01.</div>
            <div class="sb-week">Woche 02</div>
            <div class="sb-month"><span class="sb-dot" style="background:var(--feb)"></span>Februar</div>
            <div class="sb-month"><span class="sb-dot" style="background:var(--mar)"></span>März</div>
          </div>
          <div class="main-pane">
            <div class="context-bar">
              <span class="chip-btn">◀ Index</span>
              <span class="chip-btn ghost">« KW 52</span>
              <span class="chip-btn ghost">KW 02 »</span>
              <span class="spacer"></span>
              <span class="kw">29.12.2025 – 04.01.2026</span>
            </div>
            <div class="goals-row">
              <div class="goal-pill">
                <div class="gp-top"><span class="gp-title">Jahresplanung 2026</span>
                  <svg class="ring" viewBox="0 0 36 36"><circle cx="18" cy="18" r="15" fill="none" stroke="#E4E5EA" stroke-width="4"/><circle cx="18" cy="18" r="15" fill="none" stroke="#5B6EE8" stroke-width="4" stroke-dasharray="70 100" stroke-linecap="round" transform="rotate(-90 18 18)"/></circle></svg>
                </div>
                <div class="progress-bar"><span style="width:70%"></span></div>
              </div>
              <div class="goal-pill">
                <div class="gp-top"><span class="gp-title">Security-Review AWS SES</span>
                  <svg class="ring" viewBox="0 0 36 36"><circle cx="18" cy="18" r="15" fill="none" stroke="#E4E5EA" stroke-width="4"/><circle cx="18" cy="18" r="15" fill="none" stroke="#C9974B" stroke-width="4" stroke-dasharray="35 100" stroke-linecap="round" transform="rotate(-90 18 18)"/></circle></svg>
                </div>
                <div class="progress-bar"><span style="width:35%; background:var(--brass);"></span></div>
              </div>
            </div>
            <div class="week-grid">
              <div class="wg-row">
                <div><div class="dayname">Montag</div><div class="daydate">29.12.</div></div>
                <div class="wg-tasks">
                  <span class="mini-task"><span class="dot" style="background:#5B6EE8"></span>RACI-Matrix Review</span>
                </div>
              </div>
              <div class="wg-row">
                <div><div class="dayname">Dienstag</div><div class="daydate">30.12.</div></div>
                <div class="wg-tasks">
                  <span class="mini-task"><span class="dot" style="background:#C9974B"></span>SOC-Meldung abschließen</span>
                </div>
              </div>
              <div class="wg-row">
                <div><div class="dayname">Mittwoch</div><div class="daydate">31.12.</div></div>
                <div class="wg-tasks"></div>
              </div>
              <div class="wg-row today">
                <div><div class="dayname">Donnerstag</div><div class="daydate">01.01.</div></div>
                <div class="wg-tasks">
                  <span class="mini-task"><span class="dot" style="background:#5B6EE8"></span>Executive Summary</span>
                  <span class="mini-task"><span class="dot" style="background:#8A8D98"></span>Rückmeldung R+V</span>
                </div>
              </div>
              <div class="wg-row">
                <div><div class="dayname">Freitag</div><div class="daydate">02.01.</div></div>
                <div class="wg-tasks">
                  <span class="mini-task"><span class="dot" style="background:#5B6EE8"></span>Workshop vorbereiten</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      <div class="frame-caption">
        <div class="cap-title">iPad / Mac — Sidebar &amp; Wochenübersicht</div>
        <div class="cap-body">Jahr→Monat→Woche→Tag als aufklappbarer Baum (Ebene 2 des Papier-Konzepts),
          Kontextleiste oben entspricht exakt der Navigationsleiste „Index · Woche · ◀ ▶".</div>
      </div>
    </div>

    <!-- ================= MENU BAR ================= -->
    <div class="frame-block">
      <div class="menubar-mock">
        <div class="mb-bar">
          <span class="mb-icon"></span><span class="mb-icon active"></span><span class="mb-icon"></span>
        </div>
        <div class="popover">
          <h4>Schnell erfassen</h4>
          <input class="pop-input" placeholder="Was steht an?" value="Foliensatz für Steering-Meeting" readonly>
          <div class="pop-row-label">Priorität</div>
          <div class="pop-chips">
            <span class="pop-chip sel" style="background:#E0574D;border-color:#E0574D;color:#fff;">A</span>
            <span class="pop-chip">B</span>
            <span class="pop-chip">C</span>
          </div>
          <div class="pop-row-label">Wochenziel verankern</div>
          <div class="pop-chips">
            <span class="pop-chip sel">Jahresplanung 2026</span>
            <span class="pop-chip">Security-Review</span>
            <span class="pop-chip">Kein Ziel</span>
          </div>
          <div class="pop-actions">
            <span class="btn secondary">Abbrechen</span>
            <span class="btn primary">Sichern</span>
          </div>
        </div>
      </div>
      <div class="frame-caption">
        <div class="cap-title">macOS — Menüleisten-Erfassung</div>
        <div class="cap-body">Aufgabe erfassen und sofort an ein Wochenziel verankern, ohne das
          Hauptfenster zu öffnen — für den schnellen Griff zwischendurch.</div>
      </div>
    </div>

    <!-- ================= JAHRESÜBERSICHT (MAC) ================= -->
    <div class="frame-block">
      <div class="mac-window">
        <div class="titlebar">
          <span class="traffic t-red"></span><span class="traffic t-yellow"></span><span class="traffic t-green"></span>
          <span class="wtitle">Anker — Jahresübersicht</span>
        </div>
        <div class="mac-body">
          <div class="sidebar">
            <div class="sb-search">⌕ Ziele, Aufgaben, Notizen</div>
            <div class="sb-year">2026</div>
            <div class="sb-month"><span class="sb-dot" style="background:var(--jan)"></span>Januar</div>
            <div class="sb-month"><span class="sb-dot" style="background:var(--feb)"></span>Februar</div>
            <div class="sb-month"><span class="sb-dot" style="background:var(--mar)"></span>März</div>
            <div class="sb-month"><span class="sb-dot" style="background:var(--apr)"></span>April</div>
            <div class="sb-month"><span class="sb-dot" style="background:var(--mai)"></span>Mai</div>
          </div>
          <div class="main-pane">
            <div class="year-toolbar"><h3>2026 — 52 Wochen, 8 von 12 Monaten mit erreichten Zielen</h3></div>
            <div class="month-tile-grid">
              <div class="month-tile now" style="background:var(--jan)"><span class="mt-name">Januar</span><span class="mt-stat">3/4 Ziele erreicht</span></div>
              <div class="month-tile" style="background:var(--feb)"><span class="mt-name">Februar</span><span class="mt-stat">—</span></div>
              <div class="month-tile" style="background:var(--mar)"><span class="mt-name">März</span><span class="mt-stat">—</span></div>
              <div class="month-tile" style="background:var(--apr)"><span class="mt-name">April</span><span class="mt-stat">—</span></div>
              <div class="month-tile" style="background:var(--mai)"><span class="mt-name">Mai</span><span class="mt-stat">—</span></div>
              <div class="month-tile" style="background:var(--jun)"><span class="mt-name">Juni</span><span class="mt-stat">—</span></div>
              <div class="month-tile" style="background:var(--jul)"><span class="mt-name">Juli</span><span class="mt-stat">—</span></div>
              <div class="month-tile" style="background:var(--aug)"><span class="mt-name">August</span><span class="mt-stat">—</span></div>
              <div class="month-tile" style="background:var(--sep)"><span class="mt-name">September</span><span class="mt-stat">—</span></div>
              <div class="month-tile" style="background:var(--okt)"><span class="mt-name">Oktober</span><span class="mt-stat">—</span></div>
              <div class="month-tile" style="background:var(--nov)"><span class="mt-name">November</span><span class="mt-stat">—</span></div>
              <div class="month-tile" style="background:var(--dez)"><span class="mt-name">Dezember</span><span class="mt-stat">—</span></div>
            </div>
          </div>
        </div>
      </div>
      <div class="frame-caption">
        <div class="cap-title">Mac — Jahresübersicht</div>
        <div class="cap-body">Digitale Entsprechung der Index-Seite aus der Papier-Vorlage: 12 Monatskacheln
          in Originalfarbe, Tippen öffnet die erste Wochenübersicht des Monats.</div>
      </div>
    </div>

    <!-- ================= WOCHENRÜCKBLICK (iPhone) ================= -->
    <div class="frame-block">
      <div class="iphone">
        <div class="iphone-screen">
          <div class="dynamic-island"></div>
          <div class="status-row"><span>9:41</span><span>●●● 5G 87%</span></div>
          <div class="nav-title">
            <div class="date">KW 01 · 29.12. – 04.01.</div>
            <h2>Wochenrückblick</h2>
          </div>
          <div class="scroll-area" style="padding-top:6px;">
            <div class="goal-banner" style="background:linear-gradient(135deg,#EEF0FF,#EAF7EE); border-color:#DCE1FA;">
              <div class="anchor-badge" style="background:var(--success);">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.4"><path d="M4 12l5 5L20 6"/></svg>
              </div>
              <div class="txt">
                <div class="lbl">Ziele erreicht</div>
                <div class="val">3 von 4 Wochenzielen</div>
              </div>
            </div>

            <div class="section-label">Zielverlauf</div>
            <div class="task-card">
              <div class="task-check" style="background:var(--success); border-color:var(--success);"></div>
              <div class="task-body"><div class="title">Jahresplanung 2026</div></div>
            </div>
            <div class="task-card">
              <div class="task-check" style="background:var(--success); border-color:var(--success);"></div>
              <div class="task-body"><div class="title">Security-Review AWS SES</div></div>
            </div>
            <div class="task-card">
              <div class="task-check" style="background:var(--success); border-color:var(--success);"></div>
              <div class="task-body"><div class="title">Workshop Product Owner Lead</div></div>
            </div>
            <div class="task-card">
              <div class="task-check"></div>
              <div class="task-body"><div class="title">FZulG-Bewertung abschließen</div>
                <div class="goal-ref" style="color:var(--brass);">→ automatisch nach KW 02 verschoben</div>
              </div>
            </div>

            <div class="section-label">Rückblick</div>
            <div class="task-card" style="display:block;">
              <div style="font-size:12px; color:var(--muted); margin-bottom:8px;">Was nimmst du mit in die nächste Woche?</div>
              <div style="border:1px solid var(--line); border-radius:8px; padding:10px; font-size:12.5px; color:#9598A6;">Notiz hinzufügen …</div>
            </div>
          </div>
        </div>
      </div>
      <div class="frame-caption">
        <div class="cap-title">iPhone — Wochenrückblick</div>
        <div class="cap-body">Automatische Zusammenfassung zum Wochenende: erreichte Ziele, offene
          Punkte wandern automatisch in die neue Woche, Platz für eine kurze Reflexion.</div>
      </div>
    </div>

    <!-- ================= ZIEL-DETAIL (Mac) ================= -->
    <div class="frame-block">
      <div class="mac-window" style="width:520px;">
        <div class="titlebar">
          <span class="traffic t-red"></span><span class="traffic t-yellow"></span><span class="traffic t-green"></span>
          <span class="wtitle">Ziel — Jahresplanung 2026</span>
        </div>
        <div style="display:flex; flex-direction:column; height:430px; background:#fff; overflow:hidden;">
          <div class="detail-head">
            <svg class="detail-ring-big" viewBox="0 0 36 36"><circle cx="18" cy="18" r="15" fill="none" stroke="#E4E5EA" stroke-width="3.5"/><circle cx="18" cy="18" r="15" fill="none" stroke="#5B6EE8" stroke-width="3.5" stroke-dasharray="70 100" stroke-linecap="round" transform="rotate(-90 18 18)"/></svg>
            <div>
              <h3>Jahresplanung 2026</h3>
              <div class="sub">Wochenziel · KW 01 · verankert seit Mo 29.12.</div>
            </div>
          </div>
          <div class="detail-stats">
            <div class="dstat"><b>7</b><span>Aufgaben</span></div>
            <div class="dstat"><b>5</b><span>Erledigt</span></div>
            <div class="dstat"><b>3</b><span>Tage aktiv</span></div>
          </div>
          <div class="detail-timeline">
            <div class="tl-day"><div class="tld-lbl">Mo</div><div class="tl-bar"><span style="height:80%"></span></div></div>
            <div class="tl-day"><div class="tld-lbl">Di</div><div class="tl-bar"><span style="height:40%"></span></div></div>
            <div class="tl-day"><div class="tld-lbl">Mi</div><div class="tl-bar"><span style="height:0%"></span></div></div>
            <div class="tl-day"><div class="tld-lbl">Do</div><div class="tl-bar"><span style="height:100%"></span></div></div>
            <div class="tl-day"><div class="tld-lbl">Fr</div><div class="tl-bar"><span style="height:60%"></span></div></div>
            <div class="tl-day"><div class="tld-lbl">Sa</div><div class="tl-bar"><span style="height:0%"></span></div></div>
            <div class="tl-day"><div class="tld-lbl">So</div><div class="tl-bar"><span style="height:0%"></span></div></div>
          </div>
          <div class="detail-tasklist">
            <div class="dt-day-label">Donnerstag, 01.01.</div>
            <div class="dt-row"><div class="dt-check done"></div>Executive Summary finalisieren</div>
            <div class="dt-row muted"><div class="dt-check done"></div>Feedback-Runde einplanen</div>
            <div class="dt-day-label">Freitag, 02.01.</div>
            <div class="dt-row"><div class="dt-check"></div>Workshop-Agenda abstimmen</div>
          </div>
        </div>
      </div>
      <div class="frame-caption">
        <div class="cap-title">Mac — Ziel-Detail</div>
        <div class="cap-body">Zeigt alle an ein Ziel verankerten Aufgaben tagesübergreifend plus
          Aktivitätsverlauf — die "Anker-Linie" umgekehrt betrachtet: vom Ziel zu allen Tagen.</div>
      </div>
    </div>

    <!-- ================= ONBOARDING (iPhone) ================= -->
    <div class="frame-block">
      <div class="iphone">
        <div class="iphone-screen">
          <div class="dynamic-island"></div>
          <div class="onboard-wrap">
            <div class="onboard-icon">
              <svg width="34" height="34" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="1.8"><path d="M12 3v14M8 7a4 4 0 0 0 8 0M5 13a7 7 0 0 0 14 0M12 21c-2 0-3.5-1-3.5-1"/><circle cx="12" cy="4.2" r="1.4" fill="#fff" stroke="none"/></svg>
            </div>
            <h2>Verankere deine Woche</h2>
            <p>Setze bis zu vier Wochenziele. Jede Tagesaufgabe, die du erledigst, bleibt sichtbar
               mit ihrem Ziel verbunden — damit der Tag nie den Bezug zur Woche verliert.</p>
            <div class="onboard-dots"><span class="active"></span><span></span><span></span></div>
            <div class="onboard-btn">Erstes Wochenziel setzen</div>
          </div>
        </div>
      </div>
      <div class="frame-caption">
        <div class="cap-title">iPhone — Onboarding</div>
        <div class="cap-body">Erklärt das Kernprinzip in einem Satz, bevor die erste Aufgabe angelegt
          wird — entscheidend, damit „verankern" sofort verstanden wird.</div>
      </div>
    </div>

    <!-- ================= WIDGETS ================= -->
    <div class="frame-block">
      <div class="wallpaper">
        <div class="widget-medium">
          <div class="wlbl">Heutiger Fokus</div>
          <div class="wgoal">↳ Jahresplanung 2026</div>
          <div class="wtask"><span class="wc"></span> Executive Summary finalisieren</div>
          <div class="wtask"><span class="wc"></span> Rückmeldung an R+V senden</div>
        </div>
        <div class="lockrow">
          <div class="widget-lock">
            <svg viewBox="0 0 36 36"><circle cx="18" cy="18" r="15" fill="none" stroke="rgba(255,255,255,.25)" stroke-width="3.5"/><circle cx="18" cy="18" r="15" fill="none" stroke="#fff" stroke-width="3.5" stroke-dasharray="53 100" stroke-linecap="round" transform="rotate(-90 18 18)"/></svg>
            <span class="wl-txt">2/4</span>
          </div>
          <div class="lock-caption">Sperrbildschirm-Widget —<br>Fortschritt Wochenziele</div>
        </div>
      </div>
      <div class="frame-caption">
        <div class="cap-title">Home Screen &amp; Sperrbildschirm-Widgets</div>
        <div class="cap-body">Fokus des Tages und Wochenzielfortschritt, ohne die App zu öffnen —
          nutzt WidgetKit auf iOS, iPadOS und macOS gleichermaßen.</div>
      </div>
    </div>

    <!-- ================= APPLE WATCH ================= -->
    <div class="frame-block">
      <div class="watch">
        <div class="watch-screen">
          <div class="watch-time">9:41</div>
          <div class="watch-ring-row">
            <svg width="46" height="46" viewBox="0 0 36 36"><circle cx="18" cy="18" r="15" fill="none" stroke="#26272E" stroke-width="4"/><circle cx="18" cy="18" r="15" fill="none" stroke="#5B6EE8" stroke-width="4" stroke-dasharray="53 100" stroke-linecap="round" transform="rotate(-90 18 18)"/></svg>
          </div>
          <div class="watch-title">Jahresplanung 2026</div>
          <div class="watch-sub">2 von 4 Aufgaben heute</div>
          <div class="watch-task"><span class="wc2 done"></span> Executive Summary</div>
          <div class="watch-task"><span class="wc2 done"></span> Team-Sync</div>
          <div class="watch-task"><span class="wc2"></span> Rückmeldung R+V</div>
        </div>
      </div>
      <div class="frame-caption">
        <div class="cap-title">Apple Watch — Komplikation &amp; App</div>
        <div class="cap-body">Tagesfortschritt am Handgelenk abhaken, ohne das iPhone zu zücken —
          Teil des V2-Ausblicks aus dem Produktkonzept.</div>
      </div>
    </div>

  </div>

</body>
</html>
```

---

## 3. Design-Tokens (aus dem HTML abzuleitende SwiftUI-Konstanten)

Lege zuerst eine `Theme.swift` mit exakt diesen Werten an, referenziere sie überall statt Rohwerten:

```swift
enum AnkerColor {
    static let indigo       = Color(hex: "#5B6EE8")
    static let indigoDark   = Color(hex: "#3F4FBF")
    static let brass        = Color(hex: "#C9974B")
    static let ink          = Color(hex: "#1C1E27")
    static let paper        = Color(hex: "#F7F7FA")
    static let card         = Color.white
    static let line         = Color(hex: "#E4E5EA")
    static let lineSoft     = Color(hex: "#EDEEF2")
    static let muted        = Color(hex: "#8A8D98")
    static let success      = Color(hex: "#34C759")
    static let prioA        = Color(hex: "#E0574D")

    static let month: [Color] = ["#8FA8E8","#7FCDA8","#B9D97A","#F0C955",
                                  "#F0A968","#F09EA9","#C79BE8","#A79BE8",
                                  "#7FB4E8","#6FD6C4","#AEB0BA","#E8B98A"].map(Color.init(hex:))
}

enum AnkerRadius { static let card: CGFloat = 11; static let pill: CGFloat = 14; static let sheet: CGFloat = 13 }
enum AnkerSpacing { static let screenPadding: CGFloat = 20; static let stack: CGFloat = 10 }
```

Typografie: durchgängig `-apple-system` → in SwiftUI das native System-Font verwenden (`.system(size:weight:)`), **keine** Custom-Fonts einbauen. Größenreferenz aus dem HTML: Screen-Titel 22pt/700, Sektionslabel 11pt/700 uppercase, Kartentitel 13pt/600, Fließtext/Meta 10–12.5pt/500.

---

## 4. Architektur

- **Xcode-Projekt** mit Targets: `Anker` (iOS/iPadOS), `Anker macOS` (oder ein multiplattform-Target via `#if os(...)`), `AnkerWidgets` (WidgetKit-Extension), optional `Anker Watch App`.
- Gemeinsamer Code (Datenmodell, Business-Logik, Theme) in einem lokalen Swift Package `AnkerKit`, von allen Targets importiert.
- **Persistenz:** SwiftData mit `ModelConfiguration(cloudKitDatabase: .automatic)` für iCloud-Sync über den privaten Container.
- **Kalender:** `EventKit` read-only für die Zeitplan-Spalte (Termine anzeigen), Schreibzugriff optional über einen Feature-Flag.
- **Navigation:** `NavigationSplitView` auf iPad/Mac (Sidebar / Wochenliste / Detail), `NavigationStack` auf iPhone.
- **Widgets/Watch:** eigene, schlanke Timeline-Provider, die nur lesend auf den SwiftData-Store zugreifen (App Group / shared CloudKit-Container).

### Datenmodell (`@Model`-Klassen)

```swift
@Model final class Goal {
    var id: UUID
    var title: String
    var colorHex: String
    var week: Week?
    @Relationship(deleteRule: .nullify, inverse: \Task.linkedGoal)
    var tasks: [Task] = []
    var progress: Double { tasks.isEmpty ? 0 : Double(tasks.filter(\.isDone).count) / Double(tasks.count) }
}

@Model final class Week {
    var id: UUID
    var isoYear: Int
    var isoWeek: Int
    var monday: Date
    var sunday: Date
    @Relationship(deleteRule: .cascade) var goals: [Goal] = []
    @Relationship(deleteRule: .cascade) var days: [Day] = []
}

@Model final class Day {
    var id: UUID
    var date: Date
    var focusNote: String?
    var week: Week?
    @Relationship(deleteRule: .cascade) var tasks: [Task] = []
    @Relationship(deleteRule: .cascade) var timeBlocks: [TimeBlock] = []
    var notes: String?
}

enum Priority: String, Codable, CaseIterable { case a, b, c }

@Model final class Task {
    var id: UUID
    var title: String
    var priority: Priority
    var isDone: Bool = false
    var order: Int
    var day: Day?
    var linkedGoal: Goal?
}

@Model final class TimeBlock {
    var id: UUID
    var startTime: Date
    var endTime: Date
    var title: String
    var day: Day?
    var linkedEventIdentifier: String?
}
```

`linkedGoal` ist zentral: Jede UI, die eine Aufgabe zeigt, muss optional einen kleinen Anker-Verweis auf `linkedGoal?.title` rendern (siehe `.goal-ref` im HTML).

---

## 5. Screens → SwiftUI-Views (Mapping)

Baue in dieser Reihenfolge, jede View exakt nach ihrem HTML-Abschnitt oben:

| # | HTML-Abschnitt | SwiftUI-View | Plattform | Kernverhalten |
|---|---|---|---|---|
| 1 | `iPHONE` („Heute") | `TodayView` | iOS | Wochenstreifen (7 `WeekDot`), Zielbanner, Zeitplan-Liste, Prio-A/B/C-Sections, FAB → `NewTaskSheet` |
| 2 | `iPAD / MAC` | `WeekOverviewView` + `SidebarView` | iPadOS/macOS | `NavigationSplitView`, Sidebar-Baum Jahr▸Monat▸Woche▸Tag, Kontextleiste mit Index/◀/▶-Buttons, Zielkarten mit Ring, Wochenraster |
| 3 | `MENU BAR` | `QuickCapturePopover` | macOS | `MenuBarExtra` mit `.window`-Style, Textfeld, Prio-Chips, Ziel-Chips |
| 4 | `JAHRESÜBERSICHT` | `YearOverviewView` | iPadOS/macOS (Startbildschirm) | 12 `MonthTile`s in `LazyVGrid`, Tap → springt zur ersten Woche des Monats |
| 5 | `WOCHENRÜCKBLICK` | `WeeklyReviewView` | iOS (auch iPad/Mac) | Erfolgs-Banner, Zielverlauf-Liste, automatische Übertragung offener Aufgaben, Reflexionsfeld |
| 6 | `ZIEL-DETAIL` | `GoalDetailView` | iPadOS/macOS | Großer Ring, Statistik-Reihe, 7-Tage-Balken (`tl-bar` → `Chart`/eigene Bars), nach Tag gruppierte Aufgabenliste |
| 7 | `ONBOARDING` | `OnboardingView` | iOS | 3-seitiges `TabView(.page)`, letzte Seite erzeugt das erste `Goal` |
| 8 | `WIDGETS` | `TodayFocusWidget` (Home, medium), `GoalProgressWidget` (Lock Screen, circular) | WidgetKit | Timeline-Provider liest aktives `Goal` + offene `Task`s |
| 9 | `APPLE WATCH` | `WatchTodayView` + Komplikation | watchOS | Ring + kompakte Aufgabenliste, Tap zum Abhaken |

Für jede Tabellenzeile: baue zuerst eine SwiftUI-Preview mit Beispieldaten (identisch zu den Werten im HTML, z. B. „Jahresplanung 2026", „3 von 4 Wochenzielen"), damit der visuelle Abgleich mit der Referenz direkt möglich ist.

---

## 6. Nicht-funktionale Anforderungen

- **Dark Mode:** Für jede Farbe aus Abschnitt 3 ein Dark-Mode-Pendant definieren (dunklerer `paper`-Ton, gleiche Akzentfarben, ggf. leicht aufgehellt für Kontrast) — im HTML nicht gezeigt, aber Pflicht für eine echte Apple-App.
- **Dynamic Type & VoiceOver:** alle Textgrößen relativ (`.font(.system(...))` mit `@ScaledMetric` wo nötig), aussagekräftige `accessibilityLabel`s besonders für Ringe/Fortschrittsanzeigen („Jahresplanung 2026, 70 Prozent erreicht").
- **Deutsch zuerst**, aber String-Catalog (`.xcstrings`) von Anfang an für spätere Lokalisierung.
- **Tests:** Unit-Tests für `Goal.progress`-Berechnung und Datumslogik (ISO-Kalenderwochen, Jahreswechsel wie in KW 01/2026 mit Tagen aus Dezember 2025); UI-Tests für den Flow „Aufgabe erstellen → an Ziel verankern → Ziel-Fortschritt aktualisiert sich".
- **Kein Tracking/Analytics durch Drittanbieter.**

---

## 7. Abnahmekriterien

- [ ] Alle 9 Screens sind als SwiftUI-Views mit Previews vorhanden und stimmen in Farbe/Radius/Abstand mit der HTML-Referenz überein
- [ ] Eine Aufgabe lässt sich beim Anlegen optional an eines von max. 4 Wochenzielen verankern; der Ziel-Fortschritt aktualisiert sich automatisch
- [ ] Jahr→Monat→Woche→Tag-Navigation funktioniert identisch auf iPad (Sidebar) und iPhone (Stack)
- [ ] iCloud-Sync zwischen zwei Geräten funktioniert für Ziele, Aufgaben und Notizen
- [ ] Home-Screen- und Lock-Screen-Widget zeigen den aktuellen Tagesfokus bzw. Wochenzielfortschritt
- [ ] Dark Mode, Dynamic Type und VoiceOver sind für alle 9 Screens getestet

---

*Hinweis für den Coding-Agenten: Beginne mit Abschnitt 4 (Architektur/Datenmodell), bestätige das Kompilieren des leeren Projekts, und arbeite dann Tabelle 5 zeilenweise ab. Frage nach, falls eine Plattform-Priorität (iPhone zuerst vs. Mac zuerst) nicht klar ist, statt sie anzunehmen.*