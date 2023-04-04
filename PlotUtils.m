classdef PlotUtils < handle
    %PLOTUTILS Constructs a class associated with a single figure.
    %
    %   Holds all figure, axes, and plot handles for manipulation. Figures 
    %   can be added with <strong>AddSeries</strong>, <strong>AddScatter</strong>, etc.. Colors and
    %   properties can be changed with <strong>SetRecipe</strong>, <strong>ColorScheme</strong>, <strong>SetLabels</strong>,
    %   etc.
    %
    %   <strong>TODOs:</strong>
    %   - Subplot Support
    %   - Animations
    
    % obj < handle means not needing to resave outside of object
    
    properties (Access = public)
        Name     % Plot Name
        Fig      % Contains Figure Handle
        Ax       % Contains Axes Handle(s)
        Handles  % Contains Plot Handle(s)
        Legend   % Contains Legend Handle
        Recipe   % Plot Recipe QuickName (Want to get rid of)
    end
    
    properties (Access = private, Hidden = true)
        Dict            % Name-Index Pairs
        TiledLayout     % Subplot Layouts
        UsingTiled      % Check Variable
        ColorSchemeName % Saved Colorscheme
    end
    
    methods (Access = public)
        %% CONSTRUCTOR
        function obj = PlotUtils(opts)
            %PLOTUTILS Constructs a class associated with a single figure
            %   Holds all figure, axes, and plot handles for manipulation.
            %   Figures can be added with ADDSERIES
            
            % ARGUMENT VARIFICATION
            arguments
                opts.Name {mustBeTextScalar} = ''
                opts.Recipe {mustBeTextScalar} = 'default'
                opts.ColorScheme {mustBeTextScalar} = 'nordwhite'
                opts.Hide {mustBeNumericOrLogical} = false;
            end
            
            % INPUT HANDLING
            if isempty(opts.Name)
                scriptpath = matlab.desktop.editor.getActiveFilename; 
                fignum = length(findobj('type','figure'))+1;
                [~, name, ~] = fileparts(scriptpath);
                name = sprintf('%sfig%i', name, fignum);
            else
                name = opts.Name;
            end
            
            obj.ColorSchemeName = opts.ColorScheme;
            
            % APPLYING
            if ~strcmpi(opts.Recipe, 'nofig')
                obj.Name = name;
                obj.Fig = figure;
                obj.Ax = gca;

                obj.SetRecipe(opts.Recipe);
                obj.ColorScheme(opts.ColorScheme);
            end
            
            % HIDING
            if opts.Hide
                obj.Fig.Visible = false;
            end
        end
        
        %% SETUP     
        function ColorScheme(obj, name)
            switch lower(name)
                case 'nord'
                    obj.Recipe.Color.fg = '#2e3440';
                    obj.Recipe.Color.bg = '#eceff4';
                    obj.Recipe.Color.series = ["#5e81ac", ...
                                               "#a3be8c", ...
                                               "#ebcb8b", ...
                                               "#d08770", ...
                                               "#bf616a", ...
                                               "#b48ead"]; 
                                           
                case 'nordwhite'
                    obj.Recipe.Color.fg = '#2e3440';
                    obj.Recipe.Color.bg = '#ffffff';
                    obj.Recipe.Color.series = ["#5e81ac", ...
                                               "#a3be8c", ...
                                               "#ebcb8b", ...
                                               "#d08770", ...
                                               "#bf616a", ...
                                               "#b48ead"]; 
                                           
                case 'nordnight'
                    obj.Recipe.Color.fg = '#eceff4';
                    obj.Recipe.Color.grid = '';
                    obj.Recipe.Color.bg = '#2e3440';
                    obj.Recipe.Color.series = ["#5e81ac", ...
                                               "#a3be8c", ...
                                               "#ebcb8b", ...
                                               "#d08770", ...
                                               "#bf616a", ...
                                               "#b48ead"];   
                    
                case 'dracula'
                    obj.Recipe.Color.fg = '#f8f8f2';
                    obj.Recipe.Color.grid = '';
                    obj.Recipe.Color.bg = '#282a36';
                    obj.Recipe.Color.series = ["#8be9fd", ...
                                               "#50fa7b", ...
                                               "#ffb86c", ...
                                               "#ff79c6", ...
                                               "#bd93f9", ...
                                               "#ff5555" ...
                                               "#f1fa8c"];   
                    
                otherwise
                    obj.Recipe.Color.fg = '#eceff4';
                    obj.Recipe.Color.bg = '#2e3440';
                    obj.Recipe.Color.series = ["#5e81ac", ...
                                               "#a3be8c", ...
                                               "#ebcb8b", ...
                                               "#d08770", ...
                                               "#bf616a", ...
                                               "#b48ead"];  
                    
            end
            
            if ~isempty(obj.Ax)
                % APPLYING
                obj.Fig.Color = obj.Recipe.Color.bg;
                obj.Ax(end).Color = obj.Recipe.Color.bg;
                obj.Ax(end).XAxis.Color = obj.Recipe.Color.fg;
                obj.Ax(end).YAxis.Color = obj.Recipe.Color.fg;
                obj.Ax(end).ZAxis.Color = obj.Recipe.Color.fg;
                obj.Ax(end).ColorOrder = hex2rgb(cellstr(obj.Recipe.Color.series));
                obj.Ax(end).LineStyleOrder = {'-', '--', ':'};
            
                % UPDATING CURRENT HANDLES OF MOST RECENT AXIS
                hNew = findall(obj.Handles, 'parent', obj.Ax(end));
                for i = 1:length(hNew)
                    if i == 1
                        cidx = 1;
                    else
                        if cidx > length(obj.Recipe.Color.series)
                            cidx = 1;
                        else
                            cidx = cidx+1;
                        end
                    end
                    h = hNew(i);
                    h.Color = obj.Recipe.Color.series(cidx);
                end
            end
        end
        
        %% UPDATES        
        function SetLabels(obj, xlabel, ylabel, zlabel)
            obj.Recipe.X.Name = xlabel;
            obj.Recipe.Y.Name = ylabel;
            if nargin > 3
                obj.Recipe.Z.Name = zlabel;
            end
            
            obj.Update;
        end
        
        function SetTitles(obj, title, subtitle)
            obj.Recipe.Title.Text = title;
            if nargin > 2
                obj.Recipe.Subtitle.Text = subtitle;
            end
            obj.Update;
        end
        
        %% PLOTTING FUNCTIONS
        function AddSeries(obj, opts)
            % ADDSERIES is a catch-all function for general plotting using
            % latex printing. Plot types change depending on inputs.
            % 
            % <strong>Function Calls:</strong>
            %   Line Plots
            %   - ADDSERIES(y = [1 2 3])
            %   - ADDSERIES(x = [1 2 3], y = [4 5 6])
            %   - ADDSERIES(x = [1 2 3], y = [4 5 6], z = [7 8 9])
            %
            %   Span Plots (Line runs entire width of plot canvas)
            %   - ADDSERIES(x = 2) Vertical Line
            %   - ADDSERIES(y = 1) Horizontal Line
            %
            %   Scatter Plots
            %   - ADDSERIES(x = [1 2 3], y = [4 5 6], Scatter = true)
            %   - ADDSERIES(x = 1, y = 2)
            %   - ADDSERIES(x = 1, y = 2, z = 3)
            % 
            % <strong>Required Inputs:</strong>
            %   - None
            % 
            % <strong>Optional Inputs:</strong>
            %   Positional Inputs
            %   - x::<strong>Vector{Double}</strong>: x-axis data
            %   - y::<strong>Vector{Double}</strong>: y-axis data
            %   - z::<strong>Vector{Double}</strong>: z-axis data
            %
            %   Plot Labelling
            %   - Name::<strong>Char/String</strong>: Name of plotted data
            %       in legend and handle
            %   - Labels::<strong>Vector{String}</strong>: String array
            %       containing labels for each axis ["X", "Y", "Z"]
            %   - Title::<strong>Char/String</strong>: Title of plot
            %   - Subtitle::<strong>Char/String</strong>: Subtitle of plot
            %
            %   Style Settings
            %   - PlotArgs::<strong>Cell{Any}</strong>: Cell array of plot
            %       options to use if not listed in below options. Plot
            %       arguments are passed as follows:
            %       PlotArgs = {'Marker', 'o', 'LineWidth', 2}
            %   - Scatter::<strong>Boolean</strong>: Toggles between line
            %       and scatter plots.
            %   - Color::<strong>Char/String/Double</strong>: Line/Marker/Fill Color 
            %       Possible Inputs:
            %           - MATLAB Colors: 'r', 'c', etc.
            %           - Hex Color Codes: '#ffffff'
            %           - Color Series Index: 1, 2, 3, etc.
            %   - Marker::<strong>Char/String</strong>: Self Explanatory
            %   - MarkerSize::<strong>Char/String</strong>: Self Explanatory
            %   - LineStyle::<strong>Char/String</strong>: Self Explanatory
            %   - LineWidth::<strong>Char/String</strong>: Self Explanatory
            %   - XLim::<strong>Vector{Double}(1,2)</strong>: Self Explanatory
            %   - YLim::<strong>Vector{Double}(2,1)</strong>: Self Explanatory
            %   - ZLim::<strong>Vector{Double}(2,1)</strong>: Self Explanatory
            %   - YScale::<strong>Char/String</strong>: Self Explanatory
            % 
            % <strong>Outputs:</strong>
            %   - None
            
            % ========================= %
            %   ARGUMENT VARIFICATION   %
            % ========================= %
            arguments
                obj
                opts.x = []
                opts.y = []
                opts.z = []
                opts.Name {mustBeTextScalar} = ''
                opts.PlotArgs = {}
                opts.Labels = []
                opts.Scatter {mustBeNumericOrLogical} = false
                opts.Title {mustBeTextScalar} = ''
                opts.Subtitle {mustBeTextScalar} = ''
                opts.Color = []
                opts.Marker {mustBeTextScalar} = ''
                opts.MarkerSize {mustBeNumeric} = 4
                opts.LineStyle {mustBeTextScalar} = ''
                opts.LineWidth {mustBeNumeric} = obj.Recipe.Line.Width
                opts.XLim {mustBeVector} = [0 0]
                opts.YLim {mustBeVector} = [0 0]
                opts.ZLim {mustBeVector} = [0 0]
                opts.YScale {mustBeTextScalar} = 'linear'
                opts.Alpha = 1
            end
            
            
            % =================== %
            %   INPUT CLEANSING   %
            % =================== %
            
            % HANDLING EMPTY X
            if isempty(opts.x) && length(opts.y) > 1
                opts.x = 1:length(opts.y);
            end
            
            % FINDING IF SPAN LINES
            lens = [length(opts.x) length(opts.y) length(opts.z)];
            if sum(lens) == 1
                linespanType = find(lens == 1);
            else
                linespanType = NaN;
            end
            
            
            % ========================= %
            %   MASTER PLOT VARIABLES   %
            % ========================= %
            
            % MARKERS
            marker = 'none';
            
            % LINE COLOR
            C = obj.Ax(end).ColorOrder;
            Cidx = obj.Ax(end).ColorOrderIndex;
            color = C(Cidx, :);
            
            % LINE STYLE
            linestyle = '-';
            
            % LEGEND VISIBILITY
            if isempty(opts.Name); vis = 'off'; else; vis = 'on'; end
            
            % ORIGINAL PLOT LIMITS
%             xlim_current = xlim;
%             ylim_current = ylim;
%             zlim_current = zlim;
            
            
            % ===================== %
            %   EDITING VARIABLES   %
            % ===================== %
            
            % HANDLING SINGLE POINT & SCATTER PLOTS
            triggers = [length(opts.x) == 1 && length(opts.y) == 1, opts.Scatter];
            condition = isempty(opts.PlotArgs) || ~any(cellfun(@(c)~isnumeric(c)&&strcmpi(c, 'LineStyle'), opts.PlotArgs));
            if any(triggers) && condition
                linestyle = 'none';
                MarkerOrder = ["o", "s", "d", "^"];
                MarkerIdx = obj.Ax(end).LineStyleOrderIndex;
                marker = MarkerOrder(MarkerIdx);
            end
            
            if ~isempty(opts.Color)
                if ischar(opts.Color) || isstring(opts.Color)
                    color = opts.Color;
                elseif length(opts.Color) >= 3
                    color = opts.Color;
                    if any(color > 1); color = color/255; end
                elseif isscalar(opts.Color)
                    color = C(opts.Color, :);
                else
                    warning('Color option not correct format')
                end
            end
            
            if ~isempty(opts.Marker)
                marker = opts.Marker; 
            end
            
            if ~isempty(opts.LineStyle)
                linestyle = opts.LineStyle;
            end          
            
            % ============ %
            %   PLOTTING   %
            % ============ %
            
            % CREATING PLOT OPTIONS
            plotOpts = {'LineWidth', opts.LineWidth, ...
                        'LineStyle', linestyle, 'Color', color, ...
                        'Marker', marker, 'MarkerFaceColor', color, ...
                        'MarkerEdgeColor', color, 'MarkerSize', opts.MarkerSize, ...
                        'HandleVisibility', vis, 'DisplayName', opts.Name, ...
                        };
            
            % SELECTING FIGURE
            figure(obj.Fig);
            
            % PLOTTING
            if isnan(linespanType)
                if isempty(opts.z)
                    plt = plot(obj.Ax(end), opts.x, opts.y, plotOpts{:});
                else
                    plt = plot3(obj.Ax(end), opts.x, opts.y, opts.z, plotOpts{:});
                end
            else
                idx = find(strcmpi(plotOpts, 'Marker'));
                plotOpts(idx:idx+7) = [];
                switch linespanType
                    case 1
                        plt = xline(obj.Ax(end), opts.x, plotOpts{:});
                    case 2
                        plt = yline(obj.Ax(end), opts.y, plotOpts{:});                        
                    case 3
                        warning('zline() not yet supported')
%                         plt = zline(obj.Ax(end), opts.z, plotOpts{:});
                        
                end
            end
            
            
            % ==================== %
            %   ALIGNING VISUALS   %
            % ==================== %

            plt.Color(4) = opts.Alpha;
            
            % SETTING LIMITS
            if strcmpi(obj.Recipe, 'trajectory') 
                axis padded equal
            elseif strcmpi(linestyle, 'none') && isempty(obj.Handles)
                axis padded
%             else
%                 ylim_current = ylim;
%                 axis tight
%                 ylim(ylim_current)
            end
            if ~all(opts.XLim == 0); xlim(opts.XLim); end
            if ~all(opts.YLim == 0); ylim(opts.YLim); end
            if ~all(opts.ZLim == 0); zlim(opts.ZLim); end
            
            % PLOT SCALES
            obj.Ax(end).YScale = opts.YScale;

            % SETTING LABELS
            if ~isempty(opts.Labels)
                if ~iscell(opts.Labels)
                    opts.Labels = cellstr(opts.Labels);
                end
                if length(opts.Labels) < 3
                    opts.Labels{3} = '';
                end
                obj.SetLabels(opts.Labels{1}, opts.Labels{2}, opts.Labels{3})      
            end
            
            % SETTING TITLES
            if ~isempty(opts.Title)
                if contains(opts.Title, '$'); opts.Title = obj.BoldMath(opts.Title); end
                title(obj.Ax(end), strcat("\textbf{", opts.Title, '}'))
            end
            
            if ~isempty(opts.Subtitle)
                subtitle(obj.Ax(end), opts.Subtitle)
            end
            
            % ENABLING LEGEND
            if strcmpi(vis, 'on'); obj.Legend = legend; end
            
            % UPDATING FIGURE ELEMENTS
            obj.Update;
            
            % CHECKING FOR 3D VIEWS
            [~, el] = view;
            if ~isempty(opts.z) && el == 90
                view(30, 30);
            end
            
            % ADDING HANDLES TO DICTIONARY
            if isempty(opts.Name)
                hname = string(length(obj.Handles)+1);
            else
                hname = opts.Name;
            end
            obj.AddHandle(plt, hname);
        end
        
        function varargout = AddContour(obj, x, y, z, opts)
            arguments
                obj
                x {mustBeVector}
                y {mustBeVector}
                z 
                opts.Type {mustBeTextScalar, ...
                    mustBeMember(opts.Type, ...
                    {'fill', '2d', '3d', 'surf', 'constraint'})} = 'fill'
                opts.Name {mustBeTextScalar} = ''
                opts.Title {mustBeTextScalar} = ''
                opts.Subtitle {mustBeTextScalar} = ''
                opts.Labels = []
                opts.Levels {mustBeNumeric} = []
                opts.ConstColor = 'r'
                opts.LineStyle = ''
            end
            
            % ================== %
            %   INPUT HANDLING   %
            % ================== %
            
            % HANDLING IF Z IS FUNCTION
            if ~isnumeric(z)
                % CREATING ARRAY
                temp = zeros(length(y), length(x));
                
                % TESTING IF FUNCTION IS CORRECTLY SET UP
                try
                    temp(1, 1) = z(x(1), y(1));
                catch
                    error('Input function in incorrect format, but be f(x, y)')
                end
                
                % FILLING ARRAY
                for j = 1:length(y)
                    for i = 1:length(x)
                        temp(j, i) = z(x(i), y(j));
                    end
                end
                
                z = temp;
            end
            
            % ======================== %
            %   SETTING PLOT OPTIONS   %
            % ======================== %
            
            % TYPE-SPECIFIC OPTIONS
            switch opts.Type
                case 'fill'
                    linestyle = '-';
                    linewidth = obj.Recipe.Line.Width;
                
                case '2d'
                    linestyle = '-';
                    linewidth = obj.Recipe.Line.Width;
                
                case '3d'
                    linestyle = '-';
                    linewidth = obj.Recipe.Line.Width;
                    
                case 'surf'
                    linestyle = 'none';
                    linewidth = obj.Recipe.Line.Width;
                
                case 'constraint'
                    linestyle = '-';
                    linewidth = obj.Recipe.Line.Width;
                    
            end

            if ~isempty(opts.LineStyle)
                linestyle = opts.LineStyle;
            end
            
            % LEGEND VISIBILITY
            if isempty(opts.Name); vis = 'off'; else; vis = 'on'; end
            
            % CREATING PLOT OPTIONS
            plotOpts = {'LineWidth', linewidth, ...
                        'LineStyle', linestyle, ...
                        'HandleVisibility', vis, 'DisplayName', opts.Name, ...
                        };
                    
            % CUSTOM LEVELS
            if ~isempty(opts.Levels) && ~strcmpi(opts.Type, 'surf')
                plotOpts(end+1:end+2) = {'LevelList', opts.Levels};
            end
            
            % HANDLING CONSTRAINTS PLOTS
            if strcmpi(opts.Type, 'constraint') && ~strcmpi(opts.Type, 'surf')
                C = obj.Ax(end).ColorOrder;
                
                if ~isempty(opts.ConstColor)
                    if ischar(opts.ConstColor) || isstring(opts.ConstColor)
                        color = opts.ConstColor;
                    elseif length(opts.ConstColor) >= 3
                        color = opts.Color;
                        if any(color > 1); color = color/255; end
                    elseif isscalar(opts.ConstColor)
                        color = C(opts.ConstColor, :);
                    else
                        warning('Color option not correct format')
                    end
                end

                lvls = [0 0];
                plotOpts(end+1:end+6) = {'LevelList', lvls, 'LineColor', color, ...
                    'LineWidth', 2};
            end
            
            % ============ %
            %   PLOTTING   %
            % ============ %
            
            switch opts.Type
                case 'fill'
                    [~, h] = contourf(x, y, z, plotOpts{:});
                    
                case '2d'
                    [~, h] = contour(x, y, z, plotOpts{:});                    
                    
                case '3d'
                    [~, h] = contour3(x, y, z, plotOpts{:});                    
                    
                case 'surf'
                    h = surf(x, y, z, plotOpts{:});                    
                    
                case 'constraint'
                    [~, h] = contour(x, y, z, plotOpts{:});
            end
            
            if ~strcmpi(opts.Type, 'constraint') 
                colormap(pmkmp(100, 'CubicYF'));
            end
            
            % ==================== %
            %   ALIGNING VISUALS   %
            % ==================== %
            
            if ~strcmpi(opts.Type, 'surf')
%                 axis equal tight
            else
                view(-40, 30);
                dataRatios = obj.Ax(end).DataAspectRatio;
                axis equal tight
                obj.Ax(end).DataAspectRatio(3) = dataRatios(3);
            end

            % SETTING LABELS
            if ~isempty(opts.Labels)
                if ~iscell(opts.Labels)
                    opts.Labels = cellstr(opts.Labels);
                end
                if length(opts.Labels) < 3
                    opts.Labels{3} = '';
                end
                obj.SetLabels(opts.Labels{1}, opts.Labels{2}, opts.Labels{3})      
            end
            
            % SETTING TITLES
            if ~isempty(opts.Title)
                if contains(opts.Title, '$'); opts.Title = obj.BoldMath(opts.Title); end
                title(obj.Ax(end), strcat("\textbf{", opts.Title, '}'))
            end
            
            if ~isempty(opts.Subtitle)
                subtitle(obj.Ax(end), opts.Subtitle)
            end
            
            % ENABLING LEGEND
            if strcmpi(vis, 'on'); obj.Legend = legend; end
            
            % UPDATING FIGURE ELEMENTS
            obj.Update;
            
            % ========== %
            %   SAVING   %
            % ========== %
            
            % ADDING HANDLES TO DICTIONARY
            if isempty(opts.Name)
                hname = string(length(obj.Handles)+1);
            else
                hname = opts.Name;
            end
            obj.AddHandle(h, hname);
            
            % =========== %
            %   VAR OUT   %
            % =========== %
            if nargout > 0
                varargout{1} = z;
            end
        end
        
        %% UTILITIES 
        function InsetPlot(obj, opts)
            
        end
        
        function EnableSubplots(obj, opts)
            
            % ARGUMENT VARIFICATION
            arguments
                obj
                opts.Flow {mustBeNumericOrLogical} = false
                opts.GridSize {mustBeVector} = [1 1]
                opts.Title {mustBeTextScalar} = ''
                opts.Subtitle {mustBeTextScalar} = ''
                opts.XLabel {mustBeTextScalar} = ''
                opts.YLabel {mustBeTextScalar} = ''
                opts.FirstTileSize {mustBeVector} = [1 1]
                opts.Direction {mustBeTextScalar, mustBeMember(opts.Direction, {'column', 'row'})} = 'column'
            end
            
            % CREATING LAYOUT
            if opts.Flow
                t = tiledlayout(obj.Fig, 'flow');
            else
                t = tiledlayout(obj.Fig, opts.GridSize(1), opts.GridSize(2));
            end
            
            t.TileSpacing = "compact";
            t.Padding = "compact";
            t.TileIndexing = [char(opts.Direction), 'major'];
            
            % TITLE
            if ~isempty(opts.Title)
                t.Title.String = strcat("\textbf{", opts.Title, '}');
                t.Title.FontSize = obj.Recipe.Title.FontSize;
                t.Title.Interpreter = obj.Recipe.Interpreter;
            end
            
            % SUBTITLE
            if ~isempty(opts.Subtitle)
                t.Subtitle.String = opts.Subtitle;
                t.Subtitle.FontSize = obj.Recipe.Subtitle.FontSize;
                t.Subtitle.Interpreter = obj.Recipe.Interpreter;
            end
            
            % XLABEL
            if ~isempty(opts.XLabel)
                t.XLabel.String = opts.XLabel;
                t.XLabel.FontSize = obj.Recipe.Label.FontSize;
                t.XLabel.Interpreter = obj.Recipe.Interpreter;
            end
            
            % YLABEL
            if ~isempty(opts.XLabel)
                t.YLabel.String = opts.YLabel;
                t.YLabel.FontSize = obj.Recipe.Label.FontSize;
                t.YLabel.Interpreter = obj.Recipe.Interpreter;
            end
            
            % SAVING TO STRUCTURE
            obj.TiledLayout = t;
            obj.UsingTiled = true;
            nexttile(obj.TiledLayout, opts.FirstTileSize);
            
            % CREATING AXES
            obj.Ax = gca;
            obj.ColorScheme(obj.ColorSchemeName);
            obj.Update;
        end
        
        function NextPlot(obj, size)
            if nargin == 2
                nexttile(obj.TiledLayout, size);
            else
                nexttile(obj.TiledLayout);
            end
            
            % APPENDING AXES
            obj.Ax(end+1) = gca;
            obj.ColorScheme(obj.ColorSchemeName);
            obj.Update;
        end
        
        function DeletePlot(obj, name)
            % PULLING DICTIONARY DATA
            values = obj.Dict.values;
            keys = obj.Dict.keys;
            values = [values{:}];
            
            % HANDLING NUMERIC NAMES
            if isnumeric(name)
                idx = find(values == name, 1, 'first');
                name = keys{idx}; 
            end
            
            % DELETING HANDLE
            deletedHandle = obj.Dict(name);
            delete(obj.Handles(deletedHandle))
            obj.Handles(deletedHandle) = [];
            
            % UPDATING DICTIONARY/MAP KEY-VALUE PAIRS
            deletedKeyValueIdx = find(values == deletedHandle, 1, 'first');
            newvalues = values;
            newvalues(deletedKeyValueIdx) = [];
            
            newkeys = keys;
            newkeys(deletedKeyValueIdx) = [];
            for i = 1:length(obj.Handles)
                if newvalues(i) > deletedHandle
                    offset = 1;
                else
                    offset = 0;
                end
                newvalues(i) = newvalues(i)-offset;
            end
            
            % REWRITING DICTIONARY
            obj.Dict = containers.Map(newkeys, newvalues);
        end
        
        function UpdatePlotData(obj, name, opts)
            arguments
                obj
                name
                opts.y {mustBeNonempty} = []
                opts.x = []
                opts.z = []
                opts.Append {mustBeNumericOrLogical} = false
            end
            
            % HANDLING NUMERIC NAMES
            if isnumeric(name)
                values = obj.Dict.values;
                keys = obj.Dict.keys;
                values = [values{:}];
                idx = find(values == name, 1, 'first');
                name = keys{idx}; 
            end
            
            % FINDING HANDLE 
            h = obj.Handles(obj.Dict(name));
            hX = h.XData; 
            hY = h.YData;
            hZ = h.ZData;
            
            % BRANCH CONDITIONS
            lengths = [length(opts.x), length(opts.y), length(opts.z)];
            cond = [isempty(opts.x) && isempty(opts.z);
                     all(diff(lengths(lengths > 0)) == 0)];
                 
            % APPENDING
            if opts.Append 
                if cond(1)
                    hY = [hY(:); opts.y(:)];
                    hX = 1:length(hY);
                    if ~isempty(hZ)
                        hZ = zeros(lengths(2), 1);
                    end
                    
                elseif cond(2)
                    hX = [hX(:); opts.x(:)];
                    hY = [hY(:); opts.y(:)];
                    if ~isempty(hZ)
                        hZ = [hZ(:); opts.z(:)];
                    end
                    
                else
                    warning('ABORTED: Data was incorrect length')
                    return
                end
                
            % REPLACING
            else
                if cond(1)
                    hY = opts.y;
                    hX = 1:length(hY);
                    if ~isempty(hZ)
                        hZ = zeros(lengths(2), 1);                        
                    end
                    
                elseif cond(2)
                    hX = opts.x;
                    hY = opts.y;
                    if ~isempty(hZ) || ~isempty(opts.z)
                        hZ = opts.z;
                    end
                    
                else
                    warning('ABORTED: Data was incorrect length')
                    return
                end
            end
                
            % APPLYING TO HANDLE
            h.XData = hX;
            h.YData = hY;
            if ~isempty(hZ)
                h.ZData = hZ;
            end
        end
        
        function Save(obj, opts)
            arguments
                obj
                opts.Ext {mustBeTextScalar} = '.png'
                opts.Path {mustBeTextScalar} = runningFileLocation
                opts.Name {mustBeTextScalar} = obj.Name
                opts.Size {mustBeVector} = [0 0]
                opts.Resolution = 200
            end
            
            % MAKING SURE PLOT IS UP TO DATE
            obj.Update;
            
            % CHECKING FILENAME FOR EXTENSION
            opts.Name = char(opts.Name);
            tf = opts.Name == '.';
            if any(tf)
                idx = find(tf, 1, 'last');
                if contains(opts.Name(idx:end), {'.png', '.eps'})
                    opts.Ext = opts.Name(idx:end);
                    opts.Name = opts.Name(1:idx-1);
                end
            end
            
            % CHECKING FOR DOCKED FIGURE
            isdocked = strcmpi(obj.Fig.WindowStyle, 'docked');
            if isdocked
                obj.Fig.WindowStyle = 'normal';
                if all(opts.Size ~= 0)
                    obj.Fig.Position(3:4) = opts.Size;
                    obj.Fig.Position(1:2) = [10 10];
                end
            end
            
            % HANDLING STRING INPUTS
            if isstring(opts.Name); opts.Name = char(opts.Name); end
            if isstring(opts.Path); opts.Path = char(opts.Path); end
            
            % SAVING
            if contains(opts.Ext, 'png')
                exportgraphics(obj.Fig, [opts.Path, opts.Name, '.png'], 'Resolution', opts.Resolution);
            elseif contains(opts.Ext, 'eps')
                exportgraphics(obj.Fig, [opts.Path, opts.Name, '.eps']);
            end
            
            % RE-DOCKING FIGURE
            if isdocked
                obj.Fig.WindowStyle = 'docked';
            end
            
            % MAKING FIGURE INVISIBLE AGAIN
%             if visBool; obj.Fig.Visible = false; end
            
            close(obj.Fig);
        end
        
        function Clear(obj)
            delete(obj.Handles);
            obj.Handles = [];
            obj.Dict = [];
            obj.Ax.ColorOrderIndex = 1;
            obj.Ax.LineStyleOrderIndex = 1;
        end
        
        function HoldColor(obj, cidx, lsidx)
            % Find way to reset color scheme when done
            if nargin < 2
                cidx = obj.Ax.ColorOrderIndex-1;
                if cidx == 0
                    cidx = length(obj.Ax.ColorOrder);
                    lsidx = obj.Ax.LineStyleOrderIndex-1;
                else
                    lsidx = obj.Ax.LineStyleOrderIndex;
                end
            end
            if nargin > 1 && nargin < 3
                lsidx = 1;
            end
            
            obj.Ax.ColorOrderIndex = 1;
            obj.Ax.LineStyleOrderIndex = 1;
            
            c = obj.Ax.ColorOrder(cidx, :);
            ls = obj.Ax.LineStyleOrder{lsidx};
            
            obj.Ax.ColorOrder = c;
            obj.Ax.LineStyleOrder = ls;
        end
        
        function SetPadding(obj, type)
            switch lower(type)
                case 'timeseries'
%                     ylim_current = obj.Ax(end).YLim;
%                     axis tight
%                     ylim(obj.Ax(end), ylim_current);

                      axis tight
                      xlim_tight = obj.Ax(end).XLim;
                      axis padded
                      xlim(obj.Ax(end), xlim_tight);
                    
                case 'trajectory'
                    axis padded equal
                    
                otherwise
                    eval(sprintf('axis %s', lower(type)));
            end
        end
        
        function str = LatexExponent(~, num, format, slash)
            if nargin < 4; slash = '\'; end
            
            % CREATING STRING
            str = lower(sprintf(format, num));
            
            % FINDING SIGN
            isPositive = contains(str, '+');
            if isPositive
                sign = '';
            else
                sign = '-';
            end
            
            % CREATING LATEX STRING
            C = strsplit(str, 'e');
            C{2} = C{2}(ismember(C{2}, '1':'9'));
            str = [C{1}, slash, 'times 10^{', sign, C{2}, '}']; 
        end
    end
    
    %% PRIVATE METHODS
    methods (Access = private, Hidden = true)
        function str = BoldMath(~, str)
            str = char(str);
            idx = findS(str);
            if mod(numel(idx), 2) ~= 0
                error('Mismatch in number of $, must be divisible by 2')
            end
            for i = 1:size(idx, 1)

                str = [str(1:idx(i, 1)-1), '\boldmath{', str(idx(i, 1):idx(i, 2)), '}', str(idx(i, 2)+1:end)];
                idx = findS(str);
            end

            function idx = findS(str)                
                idx = strfind(str, '$');
                idx = reshape(idx, 2, []).';
            end
        end
        
        function AddHandle(obj, h, name)
            if isempty(obj.Handles)
                obj.Handles = h;
                obj.Dict = containers.Map(name, 1);
            else
                obj.Handles(end+1) = h;
                obj.Dict(name) = length(obj.Handles);
            end
        end
        
        function SetRecipe(obj, name, varargin)
            % DEFAULTS
            % FIGURE PROPERTIES
            r.Fig.Width = 1280;
            r.Fig.Height = 720;
            
            % AX PROPERTIES
            r.Ax.Box = 'on';
            r.Ax.Grid = 'on';
            r.Ax.MinorGrid = 'off';
            r.Ax.Padded = false;
            r.Ax.NextPlot = 'add';
            r.Ax.Keep = Inf;

            % LINE PROPERTIES
            r.Line.Width = 1;
            r.Line.Marker = 'none';
            
            % QUIVER PROPERTIES
            r.Quiver.Width = 0.5;
            r.Quiver.Marker = '.';

            % TEXT PROPERTIES
            r.Interpreter = 'latex';

            % LABEL PROPERTIES
            r.Label.FontSize = 16;
            
            % TITLES
            r.Title.Text = '';
            r.Title.FontSize = 18;
            r.Subtitle.Text = '';
            r.Subtitle.FontSize = 16;
            
            % LEGENDS
            r.Legend.FontSize = 12;
            
            switch lower(name)
                case 'trajectory'
                    % AX PROPERTIES
                    r.Ax.DataAspectRatio = [1 1 1];
                    r.Ax.Padded = true;
            end
            
            obj.Recipe = r;
            obj.Update;
        end
        
        function Update(obj)
            r = obj.Recipe;
            if ~isempty(obj.UsingTiled); fontOffset = -3; else; fontOffset = 0; end
            
            % SETTING FIGURE PROPERTIES
            if ~strcmpi(obj.Fig.WindowStyle, 'docked')
                obj.Fig.Position(3) = r.Fig.Width;
                obj.Fig.Position(4) = r.Fig.Height;
            end
            
            % SETTING AX PROPERTIES
            obj.Ax(end).Box = r.Ax.Box;
            obj.Ax(end).XGrid = r.Ax.Grid;
            obj.Ax(end).YGrid = r.Ax.Grid;
            if isfield(r.Ax, 'DataAspectRatio')
                obj.Ax(end).DataAspectRatio = r.Ax.DataAspectRatio;
            end
%             if r.Ax.Padded; axis padded; end
            obj.Ax(end).NextPlot = "add";
            
            % TICK LABELS
            obj.Ax(end).TickLabelInterpreter = 'latex';
            obj.Ax(end).FontSize = 14 + fontOffset; % Must happen before labels
            
            % SETTING LABELS
            if isfield(r, 'X')
                obj.Ax(end).XLabel.String = r.X.Name;
                obj.Ax(end).XLabel.Interpreter = r.Interpreter;
                obj.Ax(end).XLabel.FontSize = r.Label.FontSize + fontOffset;
                obj.Ax(end).YLabel.String = r.Y.Name;
                obj.Ax(end).YLabel.Interpreter = r.Interpreter;
                obj.Ax(end).YLabel.FontSize = r.Label.FontSize + fontOffset;
            end
            if isfield(r, 'Z')
                obj.Ax(end).ZLabel.String = r.Z.Name;
                obj.Ax(end).ZLabel.Interpreter = r.Interpreter;
                obj.Ax(end).ZLabel.FontSize = r.Label.FontSize + fontOffset;
            end
            
            % TITLES
            if ~isempty(obj.Ax(end).Title.String)                           % <--------- USE THIS FOR ALL OTHER SETTINGS
%                 obj.Ax(end).Title.String = r.Title.Text;
                obj.Ax(end).Title.Interpreter = r.Interpreter;
                obj.Ax(end).Title.FontSize = r.Title.FontSize + fontOffset;
%                 obj.Ax(end).Title.
            end
            if ~isempty(obj.Ax(end).Subtitle.String)
%                 obj.Ax(end).Subtitle.String = r.Subtitle.Text;
                obj.Ax(end).Subtitle.Interpreter = r.Interpreter;
                obj.Ax(end).Subtitle.FontSize = r.Subtitle.FontSize + fontOffset;
            end
            
            % LEGENDS
            if ~isempty(obj.Ax(end).Legend)
                obj.Ax(end).Legend.FontSize = r.Legend.FontSize;
                obj.Ax(end).Legend.Interpreter = r.Interpreter;
                obj.Ax(end).Legend.Color = r.Color.bg;
                obj.Ax(end).Legend.TextColor = r.Color.fg;
                obj.Ax(end).Legend.EdgeColor = r.Color.fg;
%                 obj.Ax(end).Legend.Location = 'northoutside';
                % Check position and number of strings for
                % num columns test
%                 obj.Ax(end).Legend.NumColumns = length(obj.Ax(end).Legend.String);
            end
            
        end
        
    end
end

%% HELPER FUNCTIONS
function [ rgb ] = hex2rgb(hex,range)

%% Input checks:
assert(nargin>0&nargin<3,'hex2rgb function must have one or two inputs.') 
if nargin==2
    assert(isscalar(range)==1,'Range must be a scalar, either "1" to scale from 0 to 1 or "256" to scale from 0 to 255.')
end
%% Tweak inputs if necessary: 
if iscell(hex)
    assert(isvector(hex)==1,'Unexpected dimensions of input hex values.')
    
    % In case cell array elements are separated by a comma instead of a
    % semicolon, reshape hex:
    if isrow(hex)
        hex = hex'; 
    end
    
    % If input is cell, convert to matrix: 
    hex = cell2mat(hex);
end
if strcmpi(hex(1,1),'#')
    hex(:,1) = [];
end
if nargin == 1
    range = 1; 
end
%% Convert from hex to rgb: 
switch range
    case 1
        rgb = reshape(sscanf(hex.','%2x'),3,[]).'/255;
    case {255,256}
        rgb = reshape(sscanf(hex.','%2x'),3,[]).';
    
    otherwise
        error('Range must be either "1" to scale from 0 to 1 or "256" to scale from 0 to 255.')
end
end

function folder = runningFileLocation()
    folder = fileparts(matlab.desktop.editor.getActiveFilename);
    folder = [folder, '\'];
end
