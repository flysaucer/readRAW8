function [Wavelength,Sample,Dark,Reference,Mode_data,h] = readRAW8(filename,specified_mode)
% Reads a single binary file saved by Avantes AvaSoft8 software.
% Yuanfei Jiang, 2022.02.05
% jiangyuanfei@jlu.edu.cn
% Institute of Atomic and Molecular Physics, Jilin University, P.R.China.

% specify_mode: 0 - 6
%  0  'Scope Mode'
%  1  'Scope minus Dark Mode'
%  2  'Absorbance Mode'
%  3  'Transmittance Mode'
%  4  'Reflectance Mode'
%  5  'Absolute Irradiance Mode'
%  6  'Relative Irradiance Mode'

% for example:
%  [Wavelength,Sample,Dark,Reference,Mode_data,h] = readRAW8(filename)
%  If the mode parameter is not specified, it will read the mode from data
%  file.Returns the result calculated from the read mode.
%  
%  [Wavelength,Sample,Dark,Reference,Mode_data,h] = readRAW8(filename,specify_mode)
%  If the mode parameter is specified, it will ignore the mode read from
%  data file and use the specified mode parameter.and returns the
%  calculation result of the specified mode.
%  
%  The number of pixels settings by  Factory can be read from the data file.
%  If less number of pixels be used, the actual number of pixels needs 
%  to be calculated according to the read wavelength data.
%

if nargin == 2
    if isnumeric(specified_mode) && specified_mode>=0 && specified_mode<=6
        Mode_select='specified_mode';
    end
end

if exist(filename, 'file')
    fid = fopen(filename);
else
    warning('FileError:NoFile', 'File %s does not exist\n', filename);
    return
end
mode_names={'Scope Mode','Scope minus Dark Mode','Absorbance Mode',...
    'Transmittance Mode','Reflectance Mode',...
    'Absolute Irradiance Mode','Relative Irradiance Mode'};
[~, ~, ext] = fileparts(filename);
if any(strcmpi(ext,{'.RAW8','.RWD8','.ABS8','.TRM8','.RFL8','.IRR8','.RIR8'}))
    h.filename=filename;
    frewind(fid);
    h.versionID=char(cellstr(fread(fid,5, '*char')'));
    fseek(fid,11,'bof');
    h.measure_mode=char(mode_names(fread(fid, 1, 'uint8')+1));
    fseek(fid,14,'bof');
    h.serial_number=char(cellstr(fread(fid,9,'*char')'));
    fseek(fid,24,'bof');
    h.friendly_name=strtrim(char(cellstr(fread(fid,9,'*char')')));
    fseek(fid,91,'bof');
    h.total_pixels=fread(fid,1,'uint16')+1;
    h.used_pixels=find_used_pixels(fid,h.total_pixels);
    fseek(fid,93,'bof');
    h.integeration_time_ms=fread(fid,1,'single');
    fseek(fid,101,'bof');
    h.Nrofaverages=fread(fid,1,'uint8');
    fseek(fid,107,'bof');
    h.Nrofsmoothingpixels=fread(fid,1,'uint8');
    h.Acquisition_date=calc_date(fid);
    h.Comments=char(cellstr(fread(fid,129, '*char')'));
    fseek(fid,328,'bof');
    Wavelength=fread(fid,h.used_pixels,'single');
    Sample=fread(fid,h.used_pixels,'single');
    Dark=fread(fid,h.used_pixels,'single');
    Reference=fread(fid,h.used_pixels,'single');
    fclose(fid);
    h.wavelength_range=[Wavelength(1) Wavelength(end)];
    h.wavelength=Wavelength;
    h.Sample=Sample;
    h.Dark=Dark;
    h.Reference=Reference;
    if exist('Mode_select','var') && strcmp(Mode_select,'specified_mode')
        h.measure_mode=char(mode_names(specified_mode+1));
    end
    switch h.measure_mode
        case 'Scope Mode'
            Mode_data=[];
            h.Scope='Sample data only';
        case 'Scope minus Dark Mode'
            Mode_data=Sample-Dark;
            h.Scope_minus_Dark=Mode_data;
        case 'Absorbance Mode'
            Mode_data=real(-log10((Sample-Dark)./(Reference-Dark)));
            h.Absorbance=Mode_data;
        case 'Transmittance Mode'
            Mode_data=100*((Sample-Dark)./(Reference-Dark));
            h.Transmittance=Mode_data;
        case 'Reflectance Mode'
            Mode_data=100*((Sample-Dark)./(Reference-Dark));
            h.Reflectance=Mode_data;
        case 'Absolute Irradiance Mode'
            Mode_data=[];
            h.Absolute_Irradiance='Consult user manual 4.4.9';
        case 'Relative Irradiance Mode'
            Mode_data=[];
            h.Relative_Irradiance='Consult user manual 4.4.10';
    end
else
    error('Unspported file');
end

function used_pixels=find_used_pixels(fid,total_pixels)
fseek(fid,328,'bof');
wl_temp=fread(fid,total_pixels,'single');
wl_find=diff(wl_temp,2);
[I,~]=find(abs(wl_find)>0.001);
if ~isempty(I)
    used_pixels=I(1)+1;
else
    used_pixels=total_pixels;
end

function date_str=calc_date(fid)
fseek(fid, 134, 'bof');
Y1 = (dec2hex(fread(fid, 8, '*ubit4', 'b')))';
fseek(fid, 327, 'bof');
Y2 = (dec2hex(fread(fid, 2, '*ubit4', 'b')))';
fseek(fid, 198, 'bof');
YY=hex2dec(Y1([7,8,5]));
MM=hex2dec(Y1(6));
DD=hex2dec(Y1(3))*2+fix(hex2dec(Y1(4))/8);
hh=mod(hex2dec(Y1(4)),8)*4+fix(hex2dec(Y1(1))/4);
mm=hex2dec([num2str(mod(hex2dec(Y1(1)),4)),Y1(2)]);
ss=hex2dec(Y2);
date_str=datestr([YY MM DD hh mm ss],'yyyy.mm.dd hh:MM:ss');

