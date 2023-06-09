unit uFuncoes;

interface

uses SysUtils, DBTables, Db, Controls, Forms, Dialogs, PsAPI, TLHelp32,
     Windows, Messages, Classes, Graphics, StdCtrls, ExtCtrls, printers;

// Fun��es

function ConverteLatLongMetros(LatLong : String) : integer;
function CalculaIdxAltitude(seq_empresa, seq_area_geral, seq_medicao : integer) : currency;
function FaltaDlaDloMaps(seq_empresa, seq_area_geral, seq_medicao : integer) : boolean;
function MediaDistanciaCalibragem(seq_empresa, seq_area_geral, seq_medicao,
                                  altura_equipamento : integer) : integer;
function idxPlantaf(altura_Planta, altura_equipamento, vMediaDistanciaCalibragem
                    : integer) : currency;
function idxPlantafOriginal(altura_Planta, altura_equipamento, vMediaDistanciaCalibragem
                    : integer) : currency;
function alturaLidaf(altura_equipamento, distancia : integer;
                     idxPlanta : currency) : integer;
function dataInicioCiclo(seq_empresa, seq_area_geral, seq_area : integer;
                         data_evento : string) : string;
function dataFimCiclo(seq_empresa, seq_area_geral, seq_area : integer;
                         data_evento : string) : string;
function CapturaTela: TBitmap;

implementation

uses ucontrolforr;

function ConverteLatLongMetros(LatLong : String) : integer;
var xsinalLatLong, xvalorLatLong, xTestaNro : integer;

begin

  try
    xsinalLatLong := strTOint(copy(LatLong, 1, pos('.', LatLong) -1));
  except
    showmessage('Parte da latitude-longitude que corresponde ao grau inv�lida');
    result := 999999;
    exit;
  end;

  try
    xTestaNro := strTOint(copy(LatLong, pos('.', LatLong) + 1, 2));
  except
    showmessage('Parte da latitude-longitude que corresponde aos minutos inv�lida');
    result := 999999;
    exit;
  end;

  try
    xTestaNro := strTOint(copy(LatLong, pos('.', LatLong) + 3, 4));
  except
    showmessage('Parte da latitude-longitude que corresponde aos segundos inv�lida');
    result := 999999;
    exit;
  end;

  xvalorLatLong := xsinalLatLong;
  if xsinalLatLong < 0 then
    xsinalLatLong := -1
  else
    xsinalLatLong := 1;

  xvalorLatLong := xvalorLatLong * xsinalLatLong;
  xvalorLatLong := xvalorLatLong * 60 * 1852;
  xvalorLatLong := xvalorLatLong +
               (strTOint(copy(LatLong, pos('.', LatLong) + 1, 2)) * 1852);
  xvalorLatLong := xvalorLatLong +
  trunc(((strTOcurr(copy(LatLong, pos('.', LatLong) + 3, 4))/100)/60) * 1852);

  result := xvalorLatLong * xsinalLatLong;

end;

function FaltaDlaDloMaps(seq_empresa, seq_area_geral, seq_medicao : integer) : boolean;
begin

  frmControlforr.qryGeral.Close;
  frmControlforr.qryGeral.SQL.Text :=
  ' select dla' +
  ' from medicoes_escaneamentos_tb' +
  ' where seq_empresa    = :seq_empresa' +
  '   and seq_area_geral = :seq_area_geral' +
  '   and seq_medicao    = :seq_medicao' +
  '   and seq_medicoes not in' +
  '               (select m.seq_medicoes' +
  '                from medicoes_escaneamentos_tb m, lat_long_alt_tb l' +
  '                where m.dla = l.dla' +
  '                  and m.dlo = l.dlo' +
  '                  and m.seq_empresa    = :seq_empresa' +
  '                  and m.seq_area_geral = :seq_area_geral' +
  '                  and m.seq_medicao    = :seq_medicao)';

  frmControlforr.qryGeral.Params[0].AsInteger := seq_empresa;
  frmControlforr.qryGeral.Params[1].AsInteger := seq_area_geral;
  frmControlforr.qryGeral.Params[2].AsInteger := seq_medicao;

  frmControlforr.qryGeral.Params[3].AsInteger := seq_empresa;
  frmControlforr.qryGeral.Params[4].AsInteger := seq_area_geral;
  frmControlforr.qryGeral.Params[5].AsInteger := seq_medicao;

  frmControlforr.qryGeral.ExecSQL;

  if frmControlforr.qryGeral.RecordCount = 0 then
    result := false
  else
    begin
      showmessage('Existem ' + frmControlforr.qryGeral.RecordCount.ToString +
                  ' locais que n�o t�m as coordenadas do Google Maps, importe' +
                  ' primeiro');
      result := true;
    end;

end;

function CalculaIdxAltitude(seq_empresa, seq_area_geral, seq_medicao : integer) : currency;
begin

  if FaltaDlaDloMaps(seq_empresa, seq_area_geral, seq_medicao) then
    begin
      result := 999999;
      exit;
    end;

  frmControlforr.qryGeral.Close;
  frmControlforr.qryGeral.SQL.Text :=
  ' select avg(m.distancia / (m.altitude - l.altitude_solo)) as idxa' +
  ' from medicoes_escaneamentos_tb m, lat_long_alt_tb l' +
  ' where m.dla = l.dla' +
  '   and m.dlo = l.dlo' +
  '   and m.seq_empresa = :seq_empresa' +
  '   and m.seq_area_geral = :seq_area_geral' +
  '   and m.seq_medicao = :seq_medicao' +
  '   and m.calibragem = true';

  frmControlforr.qryGeral.Params[0].AsInteger := seq_empresa;
  frmControlforr.qryGeral.Params[1].AsInteger := seq_area_geral;
  frmControlforr.qryGeral.Params[2].AsInteger := seq_medicao;

  try
    frmControlforr.qryGeral.ExecSQL;
    result := frmControlforr.qryGeral.FieldByName('idxa').AsCurrency;

  except
    on E : Exception do
    begin
      ShowMessage(E.ClassName+' error raised, with message : '+E.Message);
      result := 999999;
    end;
  end;

end;

function MediaDistanciaCalibragem(seq_empresa, seq_area_geral, seq_medicao,
                                  altura_equipamento : integer) : integer;
begin

  frmControlforr.qryGeral.Close;
  frmControlforr.qryGeral.SQL.Text :=
  ' select avg(m.distancia) as mediaDistancia' +
  ' from medicoes_escaneamentos_tb m' +
  ' where m.seq_empresa = :seq_empresa' +
  '   and m.seq_area_geral = :seq_area_geral' +
  '   and m.seq_medicao = :seq_medicao' +
  '   and m.distancia <= :altura_equipamento' +
  '   and m.calibragem = true';

  frmControlforr.qryGeral.Params[0].AsInteger := seq_empresa;
  frmControlforr.qryGeral.Params[1].AsInteger := seq_area_geral;
  frmControlforr.qryGeral.Params[2].AsInteger := seq_medicao;
  frmControlforr.qryGeral.Params[3].AsInteger := altura_equipamento;

  try
    frmControlforr.qryGeral.ExecSQL;
    result := trunc(frmControlforr.qryGeral.FieldByName('mediaDistancia').AsInteger
                    * 0.966 {0.52532198881}  ); //(sqrt(2)/2));

  except
    on E : Exception do
    begin
      ShowMessage(E.ClassName+' error raised, with message : '+E.Message);
      result := 999999;
    end;
  end;

end;

function idxPlantaf(altura_Planta, altura_equipamento, vMediaDistanciaCalibragem
                    : integer) : currency;
begin
  result := (altura_Planta / (altura_equipamento - vMediaDistanciaCalibragem ));// + 0.5;
end;

function idxPlantafOriginal(altura_Planta, altura_equipamento, vMediaDistanciaCalibragem
                    : integer) : currency;
begin
  result := (altura_Planta / (altura_equipamento - vMediaDistanciaCalibragem ));
end;

function alturaLidaf(altura_equipamento, distancia : integer;
                     idxPlanta : currency) : integer;
begin
  result :=
    trunc((altura_equipamento - (distancia * 0.966 {0.52532198881} ) {(sqrt(2)/2))} ) * idxPlanta);
end;

function dataInicioCiclo(seq_empresa, seq_area_geral, seq_area : integer;
                         data_evento : string) : string;
begin

  // PROCURA DATA DE INICIO DO CICLO
  frmControlforr.qryGeral.Close;
  frmControlforr.qryGeral.SQL.Text :=
' select data_evento' +
' from eventos_tb' +
' where data_evento <= :data_evento' +
'   and seq_empresa = :seq_empresa' +
'   and seq_area_geral = :seq_area_geral' +
'   and seq_area = :seq_area' +
'   and seq_tipo_evento = :seq_tipo_evento' +
'   and cancelado <> true' +
' order by data_evento desc' +
' fetch first 1 rows only';

  frmControlforr.qryGeral.Params[0].AsString := data_evento;
  frmControlforr.qryGeral.Params[1].AsInteger := seq_empresa;
  frmControlforr.qryGeral.Params[2].AsInteger := seq_area_geral;
  frmControlforr.qryGeral.Params[3].AsInteger := seq_area;
  frmControlforr.qryGeral.Params[4].AsInteger :=
        frmControlforr.qryPadrao_sistema.
            FieldByName('seq_tipo_evento_inicio_ciclo').AsInteger;

  frmControlforr.qryGeral.Open;
  frmControlforr.qryGeral.First;

  if frmControlforr.qryGeral.RecordCount = 0 then
    result := '!@#$% - falta evento de in�cio de ciclo'
  else
    result :=
      formatDateTime('dd/mm/yyyy', frmControlforr.qryGeral.
                     FieldByName('data_evento').AsDateTime);
end;

function dataFimCiclo(seq_empresa, seq_area_geral, seq_area : integer;
                         data_evento : string) : string;
begin

  // PROCURA DATA DE FIM DO CICLO
  frmControlforr.qryGeral.Close;
  frmControlforr.qryGeral.SQL.Text :=
' select data_evento' +
' from eventos_tb' +
' where data_evento > :data_evento' +
'   and seq_empresa = :seq_empresa' +
'   and seq_area_geral = :seq_area_geral' +
'   and seq_area = :seq_area' +
'   and seq_tipo_evento = :seq_tipo_evento' +
'   and cancelado <> true' +
' order by data_evento asc' +
' fetch first 1 rows only';

  frmControlforr.qryGeral.Params[0].AsString := data_evento;
  frmControlforr.qryGeral.Params[1].AsInteger := seq_empresa;
  frmControlforr.qryGeral.Params[2].AsInteger := seq_area_geral;
  frmControlforr.qryGeral.Params[3].AsInteger := seq_area;
  frmControlforr.qryGeral.Params[4].AsInteger :=
        frmControlforr.qryPadrao_sistema.
            FieldByName('seq_tipo_evento_inicio_ciclo').AsInteger;

  frmControlforr.qryGeral.Open;

  if frmControlforr.qryGeral.RecordCount = 0 then
    result := '31/12/3000'
  else
    result :=
      formatDateTime('dd/mm/yyyy', frmControlforr.qryGeral.
                     FieldByName('data_evento').AsDateTime);
end;

function CapturaTela: TBitmap;
var
  dc:hdc;
  cv:TCanvas;
begin
  result := TBitmap.Create;
  result.Width := Screen.Width;
  result.Height := Screen.Height;
  dc := GetDc(0);
  cv := TCanvas.Create;
  cv.Handle := DC;
  result.Canvas.CopyRect(Rect(
    0, 0, Screen.Width, Screen.Height),
    cv, Rect(0,0,Screen.Width, Screen.Height));
  cv.Free;
  ReleaseDC(0, DC);
end;

end.





