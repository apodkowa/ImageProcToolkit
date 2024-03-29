function makeGif(data, outfile, renderFunc,titleFunc,figHandle,delay)
% MAKEGIF Makes a gif of the data
% Loops over last dimension of data
% Supported Syntaxes
% function makeGif(data, outfile, renderFunc,titleFunc,)
% function makeGif(data, outfile, renderFunc,titleFunc,figHandle)
% function makeGif(data, outfile, renderFunc,titleFunc,figHandle,delay)
% Example titleFunc:
%titleFunc = @(f)...
%    title(sprintf('Reg. Param: %1.1e',...
%        evalin('base',sprintf('regParamList(%f)',f))));
% Example renderFunc:
% renderFunc = @(x) set(hImg,'CData',rf2Bmode(x)-p_max);
%% Handle arguments
switch ndims(data)
    case 2
        index = @(x,ind) x(:,ind);
    case 3
        index = @(x,ind) x(:,:,ind);
    otherwise
        error('Indexing not supported for data of these dimensions.')
end

if ~exist('figHandle','var')
    figHandle = gcf;
end

if ~exist('renderFunc','var')
    renderFunc = @(x) imagesc(x);
end
if ~exist('titleFunc','var')
    titleFunc = @(f) [];
end

if ~exist('delay','var')
    delay=1;
end
if isequal(lower(outfile(end-3:end)),'.avi')
    writer = VideoWriter(outfile);
    writer.FrameRate=1/delay;
    open(writer);
    doVideo=true;
else
    doVideo=false;
end
%% 
numFrames = size(data,ndims(data));

%% Generate figure and loop over frames
figHandle = figure(figHandle);
set(figHandle,'Color',ones(3,1));

try
for f=1:numFrames
 
    %% plotting kernel
    renderFunc(index(data,f));
    %title(sprintf('Reg. Param: %1.1e',evalin('base',sprintf('regParamList(%f)',f))));
    titleFunc(f);
    %% gif utilities
    % set(gcf,'color','w'); % set figure background to white
    drawnow;
    frame = getframe(figHandle);
    if ~doVideo
        im = frame2im(frame);
        [imind,cm] = rgb2ind(im,256);

        % On the first loop, create the file. In subsequent loops, append.
        if f==1
            imwrite(imind,cm,outfile,'gif','DelayTime',delay,'loopcount',inf);
        else
            imwrite(imind,cm,outfile,'gif','DelayTime',delay,'writemode','append');
        end
    else
        writeVideo(writer,frame);
    end

end
catch exc
    if doVideo
        close(writer)
    end
    throw(exc)
end
end