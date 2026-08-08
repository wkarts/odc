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
    readonly TabControl tabs = new() { Dock = DockStyle.Fill };
    readonly TextBox createInput = Box(), createOutput = Box(), createMeta = Multi();
    readonly TextBox infoInput = Box(), infoText = Multi();
    readonly TextBox extractInput = Box(), extractOutput = Box();
    readonly TextBox editInput = Box(), editMeta = Multi();

    public StudioForm()
    {
        Text = "ODC Studio .NET 1.0"; Width = 960; Height = 720; StartPosition = FormStartPosition.CenterScreen;
        Controls.Add(tabs);
        BuildCreate(); BuildInfo(); BuildExtract(); BuildMetadata();
    }

    static TextBox Box() => new() { Width = 700 };
    static TextBox Multi() => new() { Multiline = true, ScrollBars = ScrollBars.Both, Width = 850, Height = 300, Font = new Font("Consolas", 10) };
    static Button Btn(string text, EventHandler click) { var b = new Button { Text = text, AutoSize = true }; b.Click += click; return b; }
    static void AddRow(Control parent, int y, string label, Control input, params Control[] buttons)
    {
        var l = new Label { Text = label, Left = 16, Top = y + 5, Width = 120 };
        input.Left = 140; input.Top = y; parent.Controls.Add(l); parent.Controls.Add(input);
        var x = input.Left + input.Width + 8; foreach (var b in buttons) { b.Left = x; b.Top = y; parent.Controls.Add(b); x += b.Width + 6; }
    }
    TabPage Tab(string name) { var p = new TabPage(name); tabs.TabPages.Add(p); return p; }
    string? Open(string filter) { using var d = new OpenFileDialog { Filter = filter }; return d.ShowDialog() == DialogResult.OK ? d.FileName : null; }
    string? Save(string filter) { using var d = new SaveFileDialog { Filter = filter }; return d.ShowDialog() == DialogResult.OK ? d.FileName : null; }
    static void Error(Exception ex) => MessageBox.Show(ex.Message, "ODC Studio", MessageBoxButtons.OK, MessageBoxIcon.Error);

    void BuildCreate()
    {
        var p = Tab("Criar");
        AddRow(p, 20, "Origem", createInput, Btn("Selecionar", (_,__) => { var v=Open("Todos|*.*"); if(v!=null) createInput.Text=v; }));
        AddRow(p, 60, "Destino ODC", createOutput, Btn("Destino", (_,__) => { var v=Save("ODC|*.odc"); if(v!=null) createOutput.Text=v; }));
        var l=new Label{Text="Metadata JSON",Left=16,Top=110,Width=120}; createMeta.Left=140;createMeta.Top=105;p.Controls.Add(l);p.Controls.Add(createMeta);
        var b=Btn("Criar ODC", (_,__) => { try { object? meta=null; if(!string.IsNullOrWhiteSpace(createMeta.Text)) meta=JsonSerializer.Deserialize<JsonElement>(createMeta.Text); OdcContainer.Create(createInput.Text,createOutput.Text,meta,true); MessageBox.Show("ODC criado."); } catch(Exception ex){Error(ex);} }); b.Left=140;b.Top=425;p.Controls.Add(b);
    }
    void BuildInfo()
    {
        var p=Tab("Abrir / Informações");
        AddRow(p,20,"Arquivo ODC",infoInput,Btn("Abrir",(_,__)=>{var v=Open("ODC|*.odc");if(v!=null){infoInput.Text=v;ShowInfo();}}),Btn("Validar",(_,__)=>{try{MessageBox.Show(OdcContainer.Verify(infoInput.Text)?"Arquivo íntegro.":"Arquivo inválido.");}catch(Exception ex){Error(ex);}}));
        infoText.Left=16;infoText.Top=70;infoText.Width=900;infoText.Height=520;p.Controls.Add(infoText);
    }
    void ShowInfo(){try{var i=OdcContainer.Info(infoInput.Text);infoText.Text=JsonSerializer.Serialize(i,new JsonSerializerOptions{WriteIndented=true});}catch(Exception ex){Error(ex);}}
    void BuildExtract()
    {
        var p=Tab("Extrair");
        AddRow(p,20,"Arquivo ODC",extractInput,Btn("Abrir",(_,__)=>{var v=Open("ODC|*.odc");if(v!=null)extractInput.Text=v;}));
        AddRow(p,60,"Destino",extractOutput,Btn("Destino",(_,__)=>{var v=Save("Todos|*.*");if(v!=null)extractOutput.Text=v;}));
        var b=Btn("Extrair",(_,__)=>{try{OdcContainer.Extract(extractInput.Text,extractOutput.Text);MessageBox.Show("Extração concluída.");}catch(Exception ex){Error(ex);}});b.Left=140;b.Top=105;p.Controls.Add(b);
    }
    void BuildMetadata()
    {
        var p=Tab("Editar Metadata");
        AddRow(p,20,"Arquivo ODC",editInput,Btn("Abrir",(_,__)=>{var v=Open("ODC|*.odc");if(v!=null){editInput.Text=v;try{var i=OdcContainer.Info(v);editMeta.Text=i.Metadata?.GetRawText()??"{}";}catch(Exception ex){Error(ex);}}}));
        editMeta.Left=16;editMeta.Top=70;editMeta.Width=900;editMeta.Height=450;p.Controls.Add(editMeta);
        var save=Btn("Salvar Metadata",(_,__)=>{try{var m=JsonSerializer.Deserialize<JsonElement>(editMeta.Text);OdcContainer.SetMetadata(editInput.Text,m);MessageBox.Show("Metadata atualizada.");}catch(Exception ex){Error(ex);}});save.Left=16;save.Top=540;p.Controls.Add(save);
        var remove=Btn("Remover Metadata",(_,__)=>{try{OdcContainer.SetMetadata(editInput.Text,null);editMeta.Text="{}";MessageBox.Show("Metadata removida.");}catch(Exception ex){Error(ex);}});remove.Left=160;remove.Top=540;p.Controls.Add(remove);
    }
}
