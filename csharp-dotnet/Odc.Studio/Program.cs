using System.Text.Json;
using Odc;

namespace Odc.Studio;

internal static class Program
{
    [STAThread]
    static void Main()
    {
        ApplicationConfiguration.Initialize();
        Application.Run(new StudioForm());
    }
}

internal sealed class StudioForm : Form
{
    static readonly Color Nav = Color.FromArgb(16, 24, 39);
    static readonly Color NavHover = Color.FromArgb(25, 38, 59);
    static readonly Color Blue = Color.FromArgb(37, 99, 235);
    static readonly Color Surface = Color.White;
    static readonly Color Canvas = Color.FromArgb(241, 245, 249);
    static readonly Color TextPrimary = Color.FromArgb(24, 34, 55);
    static readonly Color TextMuted = Color.FromArgb(100, 116, 139);

    readonly Panel content = new() { Dock = DockStyle.Fill, BackColor = Canvas, Padding = new Padding(28) };
    readonly Label pageTitle = new() { Text = "Criar container", AutoSize = true, Font = new Font("Segoe UI", 18, FontStyle.Bold), ForeColor = TextPrimary };
    readonly Label status = new() { Text = "Pronto", AutoEllipsis = true, ForeColor = TextMuted, Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleLeft };
    readonly Dictionary<string, Panel> pages = new();
    readonly Dictionary<string, Button> navButtons = new();

    readonly TextBox createInput = Field(), createOutput = Field(), createMeta = Editor();
    readonly TextBox infoInput = Field(), infoText = Editor();
    readonly TextBox extractOutput = Field();
    readonly TextBox editMeta = Editor();
    readonly CheckBox createCompress = new() { Text = "Compressão adaptativa", Checked = true, AutoSize = true, ForeColor = TextPrimary };

    public StudioForm()
    {
        Text = "ODC Studio .NET";
        Width = 1180;
        Height = 780;
        MinimumSize = new Size(1040, 700);
        StartPosition = FormStartPosition.CenterScreen;
        BackColor = Canvas;
        Font = new Font("Segoe UI", 9F);

        var sidebar = BuildSidebar();
        var right = new Panel { Dock = DockStyle.Fill, BackColor = Canvas };
        right.Controls.Add(content);
        right.Controls.Add(BuildHeader());
        right.Controls.Add(BuildStatusBar());

        Controls.Add(right);
        Controls.Add(sidebar);

        pages["create"] = BuildCreatePage();
        pages["inspect"] = BuildInspectPage();
        pages["metadata"] = BuildMetadataPage();
        foreach (var page in pages.Values) content.Controls.Add(page);
        ShowPage("create", "Criar container");
    }

    Panel BuildSidebar()
    {
        var panel = new Panel { Dock = DockStyle.Left, Width = 235, BackColor = Nav, Padding = new Padding(14, 18, 14, 14) };
        var brand = new Panel { Dock = DockStyle.Top, Height = 82, BackColor = Nav };
        var logo = new Label { Text = "ODC", Width = 54, Height = 54, Left = 4, Top = 4, BackColor = Color.FromArgb(29, 78, 216), ForeColor = Color.White, Font = new Font("Segoe UI", 14, FontStyle.Bold), TextAlign = ContentAlignment.MiddleCenter };
        var title = new Label { Text = "ODC Studio", Left = 70, Top = 9, Width = 135, Height = 24, ForeColor = Color.White, Font = new Font("Segoe UI", 12, FontStyle.Bold) };
        var sub = new Label { Text = ".NET / WinForms", Left = 70, Top = 34, Width = 135, Height = 18, ForeColor = Color.FromArgb(150, 168, 195), Font = new Font("Segoe UI", 8) };
        brand.Controls.AddRange([logo, title, sub]);
        panel.Controls.Add(brand);

        var nav = new FlowLayoutPanel { Dock = DockStyle.Top, Height = 210, FlowDirection = FlowDirection.TopDown, WrapContents = false, BackColor = Nav, Padding = new Padding(0, 8, 0, 0) };
        nav.Controls.Add(MakeNav("create", "+", "Criar container", "Arquivo → ODC", (_, _) => ShowPage("create", "Criar container")));
        nav.Controls.Add(MakeNav("inspect", "⌁", "Inspecionar", "Header, chunks e hash", (_, _) => ShowPage("inspect", "Inspecionar container")));
        nav.Controls.Add(MakeNav("metadata", "{ }", "Metadata", "Editar dados auxiliares", (_, _) => ShowPage("metadata", "Editar metadata")));
        panel.Controls.Add(nav);

        var local = new Panel { Dock = DockStyle.Bottom, Height = 85, BackColor = Color.FromArgb(18, 30, 49), Padding = new Padding(12) };
        local.Controls.Add(new Label { Dock = DockStyle.Top, Height = 20, Text = "●  Execução local", ForeColor = Color.FromArgb(52, 211, 153), Font = new Font("Segoe UI", 8.5f, FontStyle.Bold) });
        local.Controls.Add(new Label { Dock = DockStyle.Fill, Text = "Sem servidor obrigatório.\r\nPayload binário literal ODC1.", ForeColor = Color.FromArgb(145, 161, 185), Font = new Font("Segoe UI", 8), Padding = new Padding(0, 5, 0, 0) });
        panel.Controls.Add(local);
        return panel;
    }

    Button MakeNav(string key, string glyph, string title, string subtitle, EventHandler click)
    {
        var b = new Button
        {
            Width = 205,
            Height = 56,
            FlatStyle = FlatStyle.Flat,
            BackColor = Nav,
            ForeColor = Color.FromArgb(190, 202, 220),
            TextAlign = ContentAlignment.MiddleLeft,
            Padding = new Padding(12, 0, 0, 0),
            Text = $"{glyph}    {title}\r\n       {subtitle}",
            Font = new Font("Segoe UI", 8.5f),
            Cursor = Cursors.Hand
        };
        b.FlatAppearance.BorderSize = 0;
        b.Click += click;
        b.MouseEnter += (_, _) => { if (b.BackColor != Blue) b.BackColor = NavHover; };
        b.MouseLeave += (_, _) => { if (b.BackColor != Blue) b.BackColor = Nav; };
        navButtons[key] = b;
        return b;
    }

    Control BuildHeader()
    {
        var header = new Panel { Dock = DockStyle.Top, Height = 78, BackColor = Color.White, Padding = new Padding(28, 15, 28, 12) };
        var eyebrow = new Label { Text = "OPTICAL DATA CONTAINER", AutoSize = true, ForeColor = Color.FromArgb(130, 144, 165), Font = new Font("Segoe UI", 7.5f, FontStyle.Bold), Left = 28, Top = 13 };
        pageTitle.Left = 28; pageTitle.Top = 31;
        var chip = new Label { Text = "ODC1", AutoSize = false, Width = 58, Height = 28, TextAlign = ContentAlignment.MiddleCenter, BackColor = Color.FromArgb(239, 246, 255), ForeColor = Color.FromArgb(29, 78, 216), Font = new Font("Segoe UI", 8.5f, FontStyle.Bold), Anchor = AnchorStyles.Top | AnchorStyles.Right };
        chip.Left = header.Width - chip.Width - 28; chip.Top = 25;
        header.Resize += (_, _) => chip.Left = header.ClientSize.Width - chip.Width - 28;
        header.Controls.AddRange([eyebrow, pageTitle, chip]);
        return header;
    }

    Control BuildStatusBar()
    {
        var p = new Panel { Dock = DockStyle.Bottom, Height = 34, BackColor = Color.FromArgb(248, 250, 252), Padding = new Padding(18, 0, 18, 0) };
        p.Controls.Add(status);
        var right = new Label { Text = "ODC Studio .NET · SDK 1.1.0", Dock = DockStyle.Right, Width = 220, TextAlign = ContentAlignment.MiddleRight, ForeColor = TextMuted, Font = new Font("Segoe UI", 8) };
        p.Controls.Add(right);
        return p;
    }

    static TextBox Field() => new() { BorderStyle = BorderStyle.FixedSingle, Font = new Font("Segoe UI", 9.5f), BackColor = Color.FromArgb(251, 252, 254), ForeColor = TextPrimary };
    static TextBox Editor() => new() { Multiline = true, ScrollBars = ScrollBars.Both, AcceptsTab = true, Font = new Font("Cascadia Mono", 9), BackColor = Color.FromArgb(251, 252, 254), ForeColor = TextPrimary, BorderStyle = BorderStyle.FixedSingle };

    static Panel Card(string title, string? subtitle = null)
    {
        var p = new Panel { BackColor = Surface, Padding = new Padding(18), Margin = new Padding(0, 0, 14, 0) };
        p.Controls.Add(new Label { Text = title, Left = 18, Top = 14, Width = 380, Height = 24, ForeColor = TextPrimary, Font = new Font("Segoe UI", 11, FontStyle.Bold) });
        if (!string.IsNullOrWhiteSpace(subtitle)) p.Controls.Add(new Label { Text = subtitle, Left = 18, Top = 39, Width = 500, Height = 20, ForeColor = TextMuted, Font = new Font("Segoe UI", 8) });
        return p;
    }

    static Button Action(string text, bool primary, EventHandler click)
    {
        var b = new Button { Text = text, Height = 34, AutoSize = true, FlatStyle = FlatStyle.Flat, BackColor = primary ? Blue : Color.White, ForeColor = primary ? Color.White : TextPrimary, Font = new Font("Segoe UI", 8.5f, FontStyle.Bold), Padding = new Padding(9, 0, 9, 0), Cursor = Cursors.Hand };
        b.FlatAppearance.BorderColor = primary ? Blue : Color.FromArgb(203, 213, 225);
        b.Click += click;
        return b;
    }

    static void AddField(Control parent, string label, TextBox box, int top, Button? browse = null)
    {
        parent.Controls.Add(new Label { Text = label, Left = 18, Top = top, Width = 160, Height = 18, ForeColor = TextMuted, Font = new Font("Segoe UI", 8, FontStyle.Bold) });
        box.Left = 18; box.Top = top + 21; box.Height = 30; box.Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right;
        box.Width = parent.ClientSize.Width - 36 - (browse is null ? 0 : 110);
        parent.Controls.Add(box);
        if (browse is not null) { browse.Left = parent.ClientSize.Width - 100; browse.Top = top + 20; browse.Width = 82; browse.Anchor = AnchorStyles.Top | AnchorStyles.Right; parent.Controls.Add(browse); }
        parent.Resize += (_, _) => box.Width = parent.ClientSize.Width - 36 - (browse is null ? 0 : 110);
    }

    Panel Page() => new() { Dock = DockStyle.Fill, BackColor = Canvas, Visible = false };

    Panel BuildCreatePage()
    {
        var page = Page();
        var layout = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 2, RowCount = 1, BackColor = Canvas };
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 47)); layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 53));
        var left = Card("Arquivo e destino", "Selecione a origem e o caminho final do container."); left.Dock = DockStyle.Fill;
        var right = Card("Metadata e compactação", "JSON opcional e compressão adaptativa."); right.Dock = DockStyle.Fill;
        AddField(left, "Arquivo de origem", createInput, 76, Action("Selecionar", false, (_, _) => { var v = Open("Todos os arquivos|*.*"); if (v != null) createInput.Text = v; }));
        AddField(left, "Destino ODC", createOutput, 145, Action("Destino", false, (_, _) => { var v = Save("ODC (*.odc)|*.odc"); if (v != null) createOutput.Text = v; }));
        right.Controls.Add(new Label { Text = "METADATA JSON", Left = 18, Top = 76, Width = 160, Height = 18, ForeColor = TextMuted, Font = new Font("Segoe UI", 8, FontStyle.Bold) });
        createMeta.Left = 18; createMeta.Top = 99; createMeta.Width = 470; createMeta.Height = 290; createMeta.Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right | AnchorStyles.Bottom; createMeta.Text = "{\r\n  \"origem\": \"ODC Studio .NET\"\r\n}"; right.Controls.Add(createMeta);
        createCompress.Left = 18; createCompress.Top = 405; createCompress.Anchor = AnchorStyles.Left | AnchorStyles.Bottom; right.Controls.Add(createCompress);
        var create = Action("Criar ODC", true, (_, _) => CreateOdc()); create.Left = 18; create.Top = 442; create.Anchor = AnchorStyles.Left | AnchorStyles.Bottom; right.Controls.Add(create);
        layout.Controls.Add(left, 0, 0); layout.Controls.Add(right, 1, 0); page.Controls.Add(layout); return page;
    }

    Panel BuildInspectPage()
    {
        var page = Page();
        var top = Card("Inspeção e validação", "Leia a estrutura do container e valide o SHA-256."); top.Dock = DockStyle.Top; top.Height = 140;
        AddField(top, "Arquivo ODC", infoInput, 68, Action("Abrir", false, (_, _) => { var v = Open("ODC (*.odc)|*.odc"); if (v != null) { infoInput.Text = v; ShowInfo(); } }));
        var verify = Action("Validar SHA-256", true, (_, _) => VerifyOdc()); verify.Left = 18; verify.Top = 106; top.Controls.Add(verify);
        var body = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 2, BackColor = Canvas, Padding = new Padding(0, 14, 0, 0) };
        body.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 62)); body.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 38));
        var infoCard = Card("Informações do container"); infoCard.Dock = DockStyle.Fill; infoText.Left = 18; infoText.Top = 52; infoText.Width = 560; infoText.Height = 430; infoText.ReadOnly = true; infoText.Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right; infoText.BackColor = Color.FromArgb(13, 22, 39); infoText.ForeColor = Color.FromArgb(217, 228, 244); infoCard.Controls.Add(infoText);
        var extractCard = Card("Extrair payload", "A extração valida tamanho e hash antes de concluir."); extractCard.Dock = DockStyle.Fill; AddField(extractCard, "Destino do arquivo original", extractOutput, 76, Action("Destino", false, (_, _) => { var v = Save("Todos os arquivos|*.*"); if (v != null) extractOutput.Text = v; })); var ex = Action("Extrair original", true, (_, _) => ExtractOdc()); ex.Left = 18; ex.Top = 150; extractCard.Controls.Add(ex);
        body.Controls.Add(infoCard, 0, 0); body.Controls.Add(extractCard, 1, 0); page.Controls.Add(body); page.Controls.Add(top); return page;
    }

    Panel BuildMetadataPage()
    {
        var page = Page(); var card = Card("Editor de metadata", "Abra um ODC na aba de inspeção e edite os dados auxiliares."); card.Dock = DockStyle.Fill;
        editMeta.Left = 18; editMeta.Top = 70; editMeta.Width = 850; editMeta.Height = 440; editMeta.Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right; card.Controls.Add(editMeta);
        var save = Action("Salvar metadata", true, (_, _) => SaveMetadata()); save.Left = 18; save.Top = 525; save.Anchor = AnchorStyles.Bottom | AnchorStyles.Left; card.Controls.Add(save);
        var remove = Action("Remover metadata", false, (_, _) => RemoveMetadata()); remove.Left = 155; remove.Top = 525; remove.Anchor = AnchorStyles.Bottom | AnchorStyles.Left; card.Controls.Add(remove);
        page.Controls.Add(card); return page;
    }

    void ShowPage(string key, string title)
    {
        foreach (var (name, page) in pages) page.Visible = name == key;
        foreach (var (name, button) in navButtons) { button.BackColor = name == key ? Blue : Nav; button.ForeColor = name == key ? Color.White : Color.FromArgb(190, 202, 220); }
        pageTitle.Text = title;
    }

    string? Open(string filter) { using var d = new OpenFileDialog { Filter = filter }; return d.ShowDialog() == DialogResult.OK ? d.FileName : null; }
    string? Save(string filter) { using var d = new SaveFileDialog { Filter = filter }; return d.ShowDialog() == DialogResult.OK ? d.FileName : null; }
    void SetStatus(string text) => status.Text = text;
    static void Error(Exception ex) => MessageBox.Show(ex.Message, "ODC Studio", MessageBoxButtons.OK, MessageBoxIcon.Error);

    void CreateOdc()
    {
        try { object? meta = null; if (!string.IsNullOrWhiteSpace(createMeta.Text)) meta = JsonSerializer.Deserialize<JsonElement>(createMeta.Text); OdcContainer.Create(createInput.Text, createOutput.Text, meta, createCompress.Checked); SetStatus($"Container criado: {createOutput.Text}"); MessageBox.Show("Container ODC criado com sucesso.", "ODC Studio", MessageBoxButtons.OK, MessageBoxIcon.Information); }
        catch (Exception ex) { Error(ex); SetStatus("Falha ao criar container."); }
    }

    void ShowInfo()
    {
        try { var i = OdcContainer.Info(infoInput.Text); infoText.Text = JsonSerializer.Serialize(i, new JsonSerializerOptions { WriteIndented = true }); editMeta.Text = i.Metadata?.GetRawText() ?? "{}"; SetStatus($"ODC carregado: {i.FileName} · {i.Compression}"); }
        catch (Exception ex) { Error(ex); SetStatus("Falha ao inspecionar container."); }
    }

    void VerifyOdc()
    {
        try { var ok = OdcContainer.Verify(infoInput.Text); SetStatus(ok ? "SHA-256 válido." : "Falha de integridade."); MessageBox.Show(ok ? "Arquivo íntegro." : "Arquivo inválido.", "ODC Studio", MessageBoxButtons.OK, ok ? MessageBoxIcon.Information : MessageBoxIcon.Warning); }
        catch (Exception ex) { Error(ex); }
    }

    void ExtractOdc()
    {
        try { OdcContainer.Extract(infoInput.Text, extractOutput.Text); SetStatus($"Payload extraído: {extractOutput.Text}"); MessageBox.Show("Extração concluída.", "ODC Studio", MessageBoxButtons.OK, MessageBoxIcon.Information); }
        catch (Exception ex) { Error(ex); }
    }

    void SaveMetadata()
    {
        try { var meta = JsonSerializer.Deserialize<JsonElement>(editMeta.Text); OdcContainer.SetMetadata(infoInput.Text, meta); SetStatus("Metadata atualizada."); ShowInfo(); }
        catch (Exception ex) { Error(ex); }
    }

    void RemoveMetadata()
    {
        try { OdcContainer.SetMetadata(infoInput.Text, null); editMeta.Text = "{}"; SetStatus("Metadata removida."); ShowInfo(); }
        catch (Exception ex) { Error(ex); }
    }
}
