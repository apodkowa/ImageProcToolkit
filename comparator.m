function varargout = comparator(varargin)
% COMPARATOR Compare 2 3D matrices
% comparator(matData1, matData2)
% comparator(matData1, matData2, funcHandle)
% comparator(matData1, matData2, funcHandle, renderHandle)
%% Initialization
switch length(varargin)
    case 2
        % comparator(matData1, matData2)
        matData1 = varargin{1};
        matData2 = varargin{2};
        lineNumber = 1;
        lineDir = 'Vertical';
    case 3
        % comparator(matData1, matData2, funcHandle)
        matData1 = varargin{1};
        matData2 = varargin{2};
        lineNumber = 1;
        lineDir = 'Vertical';
        renderFunc = varargin{3};
    case 4
        % comparator(matData1, matData2, funcHandle, renderHandle)
        matData1 = varargin{1};
        matData2 = varargin{2};
        lineNumber = 1;
        lineDir = 'Vertical';
        renderFunc = varargin{3};
        evalFunc = varargin{4};
    otherwise
        error('Error: Unsupported Number of Arguments: %1.0f', length(varargin) )
end

%% Sanity checks
if ~exist('renderFunc','var') || isempty(renderFunc)
    renderFunc = @(x) x;
end
assert(nargin(renderFunc)==1,'Only one argument to renderFunc supported.');
if ~exist('evalFunc','var') || isempty(evalFunc)
    evalFunc = @(x) x;
end
assert(nargin(evalFunc)==1,'Only one argument to evalFunc supported.');
        
sliceNumber = 1;
lineData = 0;
directions = {'Vertical','Horizontal'};
if isequal(max(ndims(matData1), ndims(matData2)),3)
    directions = [directions, {'Normal'}];
end

if size(matData1,3) == 1
    matData1 = repmat(matData1,1,1,size(matData2,3));
end
if size(matData2,3) == 1
    matData2 = repmat(matData2,1,1,size(matData1,3));
end

assert(isequal(size(matData1),size(matData2)),'Data matrices have different sizes');

latAxis = 1:size(matData1,2);
axAxis = 1:size(matData1,1);
frameAxis = 1:size(matData1,3);

%% Constructors
% figure
hMainFigure = figure('Name','Comparator',...
    'Toolbar','figure'...
    ,'CloseRequestFcn',@closeUI...
    );%,'Visible','off');

% Generate Underlay axes
hUnderlayAxes1 = subplot(2,2,[1],'parent',hMainFigure);
set(hUnderlayAxes1,'Tag','hUnderlayAxes1');
blue = zeros([size(matData1,1),size(matData1,2),3]); blue(:,:,3) =1;
hUnderlayImg1 = image(latAxis,axAxis,blue);

hUnderlayAxes2 = subplot(2,2,1+[1],'parent',hMainFigure);
set(hUnderlayAxes2,'Tag','hUnderlayAxes2');
red = zeros([size(matData2,1),size(matData2,2),3]); red(:,:,1) =1;
hUnderlayImg2 = image(latAxis,axAxis,red);

% Generate image axes
hImageAxes1 = axes('Position',get(hUnderlayAxes1,'Position'));
hImageAxes1.Tag = 'hImageAxes1';
colormap(hImageAxes1,gray);

hImageAxes2 = axes('Position',get(hUnderlayAxes2,'Position'));
hImageAxes2.Tag = 'hImageAxes2';
colormap(hImageAxes2,gray);

linkaxes([hImageAxes1,hUnderlayAxes1,hImageAxes2, hUnderlayAxes2]);
hl1 = linkprop([hImageAxes1,hUnderlayAxes1],{'Position'} );
hl2 = linkprop([hImageAxes2,hUnderlayAxes2],{'Position'} );

% subplot clobbers axes, so set the position manually
hLineAxes = subplot(2,2,[3 4]);%axes('Position',[0.13 0.11 0.775 0.15]);
hLineAxes.Tag = 'hLineAxes';
grid(hLineAxes,'on');

% Generate pointer for mouse click action
hPointer = zeros(1,2);

%% Component initialization

% hToolPanel
hTPfigure = figure('Name','Comparator Tools','Menubar','none',...
    'NumberTitle','off','CloseRequestFcn',@closeUI);
hTPfigure.Position([1 3]) = [1.05*sum(hMainFigure.Position([1 3])) 0.3*hMainFigure.Position(3)];
hToolPanel = uipanel(hTPfigure,'Title','Tools');
hToolPanel.Units = hImageAxes1.Units;
% hToolPanel.Position = [0 0 0.2,sum(hImageAxes1.Position([2 4]))-hLineAxes.Position(2)];
% hToolPanel.Units = hLineAxes.Units;

hLineAxes.Position(3)  = hLineAxes.Position(3);%-1.1*hToolPanel.Position(3);
axSep = hImageAxes2.Position(1)-hImageAxes1.Position(1)-hImageAxes1.Position(3);
hImageAxes1.Position(3) = (hLineAxes.Position(3)-axSep)/2;
hImageAxes2.Position(3) = hImageAxes1.Position(3);
hImageAxes2.Position(1) = sum(hImageAxes1.Position([1 3])) + axSep;
% 
% hToolPanel.Position(1) = sum(hLineAxes.Position([1 3]))...
%     ;%+0.1*hToolPanel.Position(3);
% hToolPanel.Position(2) = hLineAxes.Position(2);

% hSlider
if length(directions)==3
    pos = hLineAxes.Position...
        + hLineAxes.Position(4)*[ 0 1 0 0];
    pos(4) = 0.044;
    hSlider = uicontrol(hToolPanel,'Style','slider','Min',1,'Max',size(matData1,3)...
        ,'Value',sliceNumber,'callback',@hSliderCallback,...
        'Units','normalized','Position',pos,...
        'SliderStep',[1/(size(matData1,3)-1), max(0.1,1/(size(matData1,3)-1))]);
    hLineAxes.Position(4) = hLineAxes.Position(4)-1.1*pos(4);
end

% lineDirButton
lineDirButton = uicontrol(hToolPanel,'Style','pushbutton',...
    ...%uicontrol(hTPfigure,'Style','pushbutton','Parent',hToolPanel,...
    'String',lineDir,'ToolTip','Line Direction',...
    'Callback',@lineDirButton_callback...
    ,'Units','normalized');
lineDirButton.Position(2) = 0.9;
lineDirButton.Position(3) = 1-2*lineDirButton.Position(1);

% makeGifButton
makeGifButton = uicontrol(hToolPanel,'Style','pushbutton',...
    'String','Make Gif','Callback',@makeGif_callback,'units','normalized');
makeGifButton.Position(3) = 1-2*makeGifButton.Position(1);
if length(directions)~=3
    makeGifButton.Visible = 'off';
end
% setAxesButton
setAxesButton = uicontrol(hToolPanel,'Style','pushbutton',...
    'String','Set Axes','units','normalized','Callback',@setAxes_callback);
setAxesButton.Position(2) = dot([1 1.5],makeGifButton.Position([2 4]));
setAxesButton.Position(3)= 1-2*setAxesButton.Position(1);

% coordTable
coordTable = uitable(hToolPanel,...
    'columnName',{'row','col','slice'},...
    'rowName',[],...
    'ColumnEditable',true(1,3),...
    'ColumnWidth',{35},...
    'data',[hPointer(:)' 1],...
    'CellEditCallback',@coordTableEditCallback,...
    'Units','normalized','Position',[0 0.675 1 0.2]...
    );
coordTable.ColumnWidth = {floor(0.95*hTPfigure.Position(3)/3)};
coordTable.Position(4) = coordTable.Extent(4);
coordTable.Position(2) = coordTable.Position(2)+coordTable.Extent(4)/2;


% caxis menu
cAxisPopUp = uicontrol(hToolPanel,'Style','popup',...
    'String',{'Auto','Left','Right','Max','Max Center','Manual'},...
    'Callback',@cAxisCallback,...
    'Tooltip', 'Color Axis', ...
    'Units','normalized',...
    'Position', [0.05, coordTable.Position(2)-0.175 0.9 0.15]);
cAxisStyle = 'Auto';

% hImg
axes(hImageAxes1)
hImg1 = imagesc(latAxis,axAxis,renderFunc(matData1(:,:,sliceNumber)));
colorbar
set(hImg1,'ButtonDownFcn',@ImageClickCallback);
set(hImageAxes1,'Color','none');
title('Left')

axes(hImageAxes2)      
hImg2 = imagesc(renderFunc(matData2(:,:,sliceNumber)));
colorbar
set(hImg2,'ButtonDownFcn',@ImageClickCallback);
set(hImageAxes2,'Color','none');
title('Right')

% linkprop([hUnderlayImg1 hImg1 hUnderlayImg2 hImg2],{'XData','YData'});

axes(hLineAxes)
lineData = evalFunc(matData1(:,lineNumber,sliceNumber));
hLine1 = plot(1:size(matData1,1),lineData); hold on;
hLine2 = plot(1:size(matData1,1),evalFunc(matData2(:,lineNumber,sliceNumber)),'r');
grid on;

%% Start GUI
updatePlots;
hMainFigure.Visible = 'on';

%% Callbacks
    function lineDirButton_callback(hObject,eventdata)
       toggleDirection;
       updatePlots;
    end

    function closeUI(hObject,eventdata)
        try delete(hMainFigure);
        catch 
        end
        try delete(hTPfigure);
        catch
        end
    end

    function makeGif_callback(hObject,eventData)
        gifName = 'comparison.gif';
        [gifName,fp] = uiputfile('*.gif','Make Gif',gifName);
        gifName = fullfile(fp,gifName);
        makeGif(permute(1:size(matData1,3),[1 3 2]),gifName,...
            @updateGif,@(x) [],hMainFigure);
        
        while true
            val = inputdlg('Frame Delay:','Enter Frame Delay',1,{'1/2'});
            [val,stat] = str2num(val{1});
            if stat && ~isequal(val,0)
                [val_num,val_den] = rat(val,1e-4);
                break;
            end
        end
        cmd = sprintf('convert -delay %1.0fx%1.0f %s %s',val_num,val_den,...
            gifName,gifName);
        system(cmd);
        
        msgbox(sprintf('Data stored in %s',gifName));
        function updateGif(i)
            hSlider.Value = i;
            hSliderCallback(hSlider,[]);
        end

    end

    function setAxes_callback(hObject, eventData)
        warning('SetAxes not supported yet!')
        prompt = {'Lat. Step'; 'Ax. Step'};
        defaults = diff([latAxis(1:2); axAxis(1:2)]')';
        if length(directions)==3
            prompt{end+1} = 'Frame Step';
            defaults(end+1) = diff(frameAxis(1:2));
        end
        defaults = num2cell(defaults);
        defaults = cellfun(@num2str,defaults,'UniformOutput',false);
        resp = inputdlg(prompt,'Set Axes',1,defaults);
        try 
            resp=cellfun(@str2num,resp);
        catch msg
            warndlg('Error processing input!')
            return
        end
        try
            validateattributes(resp,{'numeric'},{'>',0});
        catch msg
            errordlg(msg.message,'Invalid Input!')
            return
        end

        % Update hPointer
        [hPointer(1),ind(1)] = findClosest(latAxis,hPointer(1));
        [hPointer(2),ind(2)] = findClosest(axAxis,hPointer(2));
        
        % Update axes
        latOld = latAxis;
        axOld  = axAxis;
        latAxis = (0:(length(latAxis)-1))*resp(1);
        axAxis  = (0:(length( axAxis)-1))*resp(2);
        hPointer = [latAxis(ind(1)), axAxis(ind(2))];
        if length(directions)==3
            frameAxis = (0:(length(frameAxis)-1))*resp(3);
        end
        
        % Rederive limits on old axes
        % Image toolbox likes half pixel edges
        yLim=ylim(hImageAxes1)-diff(axOld(1:2))*[-0.5 0.5];
        xLim=xlim(hImageAxes1)-diff(latOld(1:2))*[-0.5 0.5];
        [~,yLim(1)] = findClosest(axOld,yLim(1));
        [~,yLim(2)] = findClosest(axOld,yLim(2));
        [~,xLim(1)] = findClosest(latOld,xLim(1));
        [~,xLim(2)] = findClosest(latOld,xLim(2));
        yLim = axAxis(yLim)+diff(axAxis(1:2))*0.5*[-1 1];
        xLim = latAxis(xLim)+diff(latAxis(1:2))*0.5*[-1 1];
        
        % Update handles
        set([hImg1,hImg2]...,'CData',renderFunc(matData(:,:,sliceNumber))...
            ,'YData',axAxis...
            ,'XData',latAxis...
        );
        set([hUnderlayImg1 hUnderlayImg2],'YData',axAxis,'XData',latAxis);
        xlim(hImageAxes1,xLim); ylim(hImageAxes1,yLim);
        xlim(hImageAxes2,xLim); ylim(hImageAxes2,yLim);
        
        updatePlots;
    end

    function cAxisCallback( objectHandle , eventData )
        styles = get(objectHandle,'String');
        style = styles{get(objectHandle, 'Value')};
        switch style
            case 'Auto'
                cAxisStyle = style;
            case 'Manual'
                cAxisStyle = style;
            case 'Left'
                cAxisStyle = style;
            case 'Right' 
                cAxisStyle = style;
            case 'Max' 
                cAxisStyle = style;
            case 'Max Center'
                cAxisStyle = style;
            otherwise 
                val = find(cellfun(@(x) isequal(x,cAxisStyle),styles));
                set(objectHandle,'Value',val);
        end
        updateCaxis();
    end

    function ImageClickCallback ( objectHandle , eventData )
        axesHandle  = get(objectHandle,'Parent');
        coordinates = get(axesHandle,'CurrentPoint'); 
        coordinates = coordinates(1,1:2);
        hPointer = coordinates;
        updatePlots;
    end

    function hSliderCallback(hObject,eventData)
        value = round(get(hObject,'Value'));
        sliceNumber = value;
        updatePlots;
        
    end
    
    function coordTableEditCallback(hObject,callbackdata)
        % magic from "uitable properties" documentation
        coordinate = eval(callbackdata.EditData);
        row = callbackdata.Indices(1);
        col = callbackdata.Indices(2);
        if col==3
            sliceNumber = min(max(1,round(coordinate)),size(matData1,3));
            set(hSlider,'Value',sliceNumber);
        else
            hObject.Data(row,col) = coordinate;
        end
        hPointer(1) = latAxis(hObject.Data(2));
        hPointer(2) = axAxis(hObject.Data(1));
        updatePlots;
    end

%% Utility functions
    function updatePlots
        figure(hMainFigure)
        
        %% Render image
        set(hImg1,'CData',renderFunc(matData1(:,:,sliceNumber))...);
            ...,'YData',axAxis...
            ...,'XData',latAxis...
        );
        set(hImg2,'CData',renderFunc(matData2(:,:,sliceNumber))...);
            ...,'YData',axAxis...
            ...,'XData',latAxis...
        );
        %set([hUnderlayImg1 hUnderlayImg2],'YData',axAxis,'XData',latAxis);
        %xlim(hImageAxes1,xLim); ylim(hImageAxes1,yLim);
        %xlim(hImageAxes2,xLim); ylim(hImageAxes2,yLim);
        
        updateCaxis();
        %% calculate axes
        %[xData, yData, cData1] = getimage(hImageAxes1);
        %[xData, yData, cData2] = getimage(hImageAxes2);
        %dx = diff(xData)/(size(cData1,2)-1);
        %dy = diff(yData)/(size(cData1,1)-1);
        %xAxis = xData(1):dx:xData(2);
        %yAxis = yData(1):dy:yData(2);
        %assert(isequal(length(latAxis),size(cData1,2)),'Error: Bad xAxis length');
        %assert(isequal(length(axAxis),size(cData1,1)),'Error: Bad yAxis length');
        [hPointer(1),ind(1)] = findClosest(latAxis,hPointer(1));
        [hPointer(2),ind(2)] = findClosest(axAxis,hPointer(2));
        set(coordTable,'data',[flipud(ind(:))' sliceNumber]);
        switch lineDir
            case 'Vertical'
                [~,lineNumber] = findClosest(latAxis,hPointer(1));
                mask = ones(size(matData1(:,:,1))); mask(:,lineNumber)=0;
                hImg1.AlphaData = mask;
                hImg2.AlphaData = mask;
%                 axes(hLineAxes)
%                 lineData = evalFunc(matData1(:,lineNumber,sliceNumber));
%                 plot(yAxis,lineData);
%                 grid on;
                set(hLine1,'XData',axAxis,...
                    'YData', evalFunc(matData1(:,lineNumber,sliceNumber)));
                set(hLine2,'XData',axAxis,...
                    'YData', evalFunc(matData2(:,lineNumber,sliceNumber)));
            case 'Horizontal'
                [~,lineNumber] = findClosest(axAxis,hPointer(2));
                mask = ones(size(matData1(:,:,1))); mask(lineNumber,:)=0;
                hImg1.AlphaData = mask;
                hImg2.AlphaData = mask;
%                 axes(hLineAxes)
%                 lineData = evalFunc(matData1(lineNumber,:,sliceNumber));
%                 plot(xAxis,lineData);
%                 grid on;
                set(hLine1,'XData',latAxis,...
                    'YData', evalFunc(matData1(lineNumber,:,sliceNumber)));
                set(hLine2,'XData',latAxis,...
                    'YData', evalFunc(matData2(lineNumber,:,sliceNumber)));

            case 'Normal'
                [hPointer(1),ind(1)] = findClosest(latAxis,hPointer(1));
                [hPointer(2),ind(2)] = findClosest(axAxis,hPointer(2));
                lineNumber = 0;
                mask = ones(size(matData1(:,:,1))); 
                mask(:,ind(1))=0; mask(ind(2),:) = 0;
                
                hImg1.AlphaData = mask;
                hImg2.AlphaData = mask;
%                 axes(hLineAxes)
%                 lineData = evalFunc(squeeze(matData1(ind(2),ind(1),:)));
%                 hLine = plot(frameAxis,lineData);
%                 hold on
%                 plot(frameAxis(sliceNumber),lineData(sliceNumber),'ro');
%                 hold off
%                 grid on;
                set(hLine1,'XData',frameAxis,...
                    'YData', evalFunc(squeeze(matData1(ind(2),ind(1),:))));
                set(hLine2,'XData',frameAxis,...
                    'YData', evalFunc(squeeze(matData2(ind(2),ind(1),:))));
            
            otherwise 
                error('Error: Invalid lineDir (%s)',lineDir');
        end
        
        % Reset Tags on figure update
        hImageAxes1.Tag = 'hImageAxes1';
        hLineAxes.Tag =  'hLineAxes';
    end

    function toggleDirection        
        if any(ismember(directions,lineDir))
            val = mod(find(ismember(directions,lineDir)),length(directions))+1;
            lineDir = directions{val};
        else 
            lineDir = 'Vertical';
        end
        lineDirButton.String = lineDir;
    end

    function updateCaxis
        % Set Clim Mode
        if isequal(cAxisStyle,'Auto')
            set([hImageAxes1 hImageAxes2],'CLimMode','auto')
            return
        elseif isequal(cAxisStyle,'Left')
            set(hImageAxes1,'CLimMode','auto');
            caxis(hImageAxes2,get(hImageAxes1,'CLim'));
            return
        elseif isequal(cAxisStyle,'Right')
            set(hImageAxes2,'CLimMode','auto');
            caxis(hImageAxes1,get(hImageAxes2,'CLim'));
            return
        else 
            set([hImageAxes1 hImageAxes2],'CLimMode','manual')
            return
        end
        %% Get Caxis
        switch cAxisStyle
            case 'Max'
                c_max = max(max(renderFunc(matData1(:,:,1))));
                c_min = min(min(renderFunc(matData1(:,:,1))));
                for k = 1:max(size(matData1,3))
                    c_max = max(c_max,...
                        max(max([renderFunc(matData1(:,:,k))...
                        renderFunc(matData2(:,:,k))])));
                    c_min = min(c_min,...
                        min(min([renderFunc(matData1(:,:,k))...
                        renderFunc(matData2(:,:,k))])));
                end
                caxis(hImageAxes1,[c_min,c_max]);
                caxis(hImageAxes2,[c_min,c_max]);
            case 'Max Center'
                c_max = max(max(abs(renderFunc(matData1(:,:,1)))));
                for k = 1:max(size(matData1,3))
                    c_max = max(c_max,...
                        max(max(abs([renderFunc(matData1(:,:,k))...
                        renderFunc(matData2(:,:,k))]))));
                end
                caxis(hImageAxes1,c_max*[-1 1]);
                caxis(hImageAxes2,c_max*[-1 1]);
            otherwise
                error('Unsupported cAxisStyle: %s',cAxisStyle);
        end
    end

    function [closestMatch,ind] = findClosest(vec,num)
        optFun = abs(vec-num);
        [~,ind] = min(optFun);
        closestMatch = vec(ind);
        assert(length(closestMatch)==1,'Multiple matches found')
    end

end
