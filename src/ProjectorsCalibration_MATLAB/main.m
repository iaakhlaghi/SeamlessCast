function main(run_id)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% INITIALIZATION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clc
close all

if nargin < 1 || isempty(run_id)
    run_id = 1;
end

%% PARAMETERS
cameras_idx       = [1]; %#ok<*NBRAK2>
all_screen_ids    = [1 2];
monitor_id        = 3;
pause_time        = 2.5;

%% CAMERA VIEW CROP PARAMETERS
camera_crop_rect = [1 1 639 479];   % [x y width height], gives 640-by-480 output
prjs_bw_mask_thr = [160 160];

%% OUTPUT IMAGE CONTROL
output_content_scale  = 0.5;          % 1 = auto-fit, <1 = zoom out, >1 = zoom in
output_content_offset = [-100 320];   % [x y] pixels, +x right, +y down

%% INTERNAL DISPLAY SETTINGS
calibration_display_mode = 'exact';
final_display_mode       = 'exact';

%% CALIBRATION PARAMETERS
projectors            = getProjectorDisplayInfo(all_screen_ids);
working_img_height    = max([projectors.native_height]);
working_img_width     = max([projectors.native_width]);
cam_calib_base_height = 1080;
cam_calib_scale       = 1.5;
Pttrn_scale           = 6;

%% CIRCULAR MASK PARAMETERS
circ_mask_cntr = [850 850];
circ_mask_rad  = 340;

%% BLENDING PARAMETERS
w_FeatherPower = 1.3;
w_Priority     = [1, 1];

%% PHOTOMETRIC EVALUATION PARAMETERS
run_captured_photometric_test = true;
photometric_gray_level = 0.5;
photometric_overlap_thr = 0.05;

%% OUTPUT SOURCE
output_mode = 'image';  % 'image' or 'video'
im_out_file = 'test.png';
video_file  = 'test.mp4';

%% VIDEO PLAYER PARAMETERS
video_frame_step = 3;        % 1 = all frames, 2 = every other frame
video_player_mode = 'fast_lut'; % 'imwarp' or 'fast_lut'

%% PLAYER CALIBRATION EXPORT
save_player_calibration = true;
player_calibration_dir = fullfile(repo_root, 'data', 'player_calibration');

%% METRICS EXPORT
save_metrics = true;
metrics_dir = fullfile(repo_root, 'results', 'calibration_metrics');

if ~exist(metrics_dir, 'dir')
    mkdir(metrics_dir);
end

metrics = struct();
metrics.created_at = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
metrics.repeatability_run_id = run_id;
metrics.num_projectors = length(all_screen_ids);
metrics.screen_ids = all_screen_ids;
metrics.camera_indices = cameras_idx;
metrics.working_img_height = working_img_height;
metrics.working_img_width  = working_img_width;
metrics.projectors = struct([]);
metrics.runtime = struct();

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% LOAD DATA
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

Pttrn     = imread('tags.png');
Pttrn     = imresize(Pttrn, Pttrn_scale, 'Method', 'nearest');
Pttrn = imcrop(Pttrn, [1 1 working_img_width-1 working_img_height-1]);
output_im_raw = imread(im_out_file);
output_im = prepareOutputImageAutoFit( ...
    output_im_raw, ...
    [working_img_height working_img_width], ...
    output_content_scale, ...
    output_content_offset);
load('cameras_stitching_saved.mat', 'cameras_stitching_saved')
load('cameras_calibration_saved.mat', 'cameras_calibration_saved')

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% BUILD PROJECTOR MASKS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

im_mask = zeros([ ...
    camera_crop_rect(4)+1, ...
    camera_crop_rect(3)+1, ...
    length(all_screen_ids)]);
t_mask_total = tic;
for i = 1:length(all_screen_ids)
    One_Scr_On_others_Off( ...
        all_screen_ids, ...
        all_screen_ids(i), ...
        projectors, ...
        calibration_display_mode);    
    pause(pause_time)
    im = snapshot_multi_cam( ...
        cameras_idx, ...
        cameras_stitching_saved, ...
        cameras_calibration_saved, ...
        camera_crop_rect);
    imshow_scr_idx(im, monitor_id)
    im_mask(:, :, i) = double(rgb2gray(im) > prjs_bw_mask_thr(i));
    imshow_scr_idx(im_mask(:, :, i), monitor_id)
    closeFiguresOnScreen(all_screen_ids(i))
end
pause(pause_time)
metrics.runtime.mask_acquisition_total_s = toc(t_mask_total);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% CALIBRATION (APRIL TAGS)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

t_calib_total = tic;
calibStats = cell(1, length(all_screen_ids));
for i = 1:length(all_screen_ids)
    for j = 1:length(all_screen_ids)
        if j == i
            displayImageOnScreen(Pttrn, all_screen_ids(j), calibration_display_mode);
        else
            blackFrame = zeros(projectors(j).native_height, projectors(j).native_width, 'uint8');
            displayImageOnScreen(blackFrame, all_screen_ids(j), calibration_display_mode);
        end
    end
    pause(pause_time)
    im_tmp = snapshot_multi_cam( ...
        cameras_idx, ...
        cameras_stitching_saved, ...
        cameras_calibration_saved, ...
        camera_crop_rect);
    im_tmp = imresize(im_tmp, [cam_calib_base_height NaN]);
    im_tmp = imresize(im_tmp, cam_calib_scale);
    t_calib_i = tic;

    [~, all_tforms{i}, calibStats{i}] = Calibration_AprilTags(Pttrn, im_tmp);

    metrics.projectors(i).screen_id = all_screen_ids(i);
    metrics.projectors(i).num_matched_tags = calibStats{i}.num_matched_tags;
    metrics.projectors(i).rms_error_px = calibStats{i}.rms_error_px;
    metrics.projectors(i).mean_error_px = calibStats{i}.mean_error_px;
    metrics.projectors(i).median_error_px = calibStats{i}.median_error_px;
    metrics.projectors(i).max_error_px = calibStats{i}.max_error_px;
    metrics.projectors(i).p95_error_px = calibStats{i}.p95_error_px;
    metrics.projectors(i).calibration_time_s = toc(t_calib_i);

    metrics.projectors(i).error_vector_px = calibStats{i}.error_vector_px;
    metrics.projectors(i).matched_input_xy = calibStats{i}.matched_input_xy;
    metrics.projectors(i).matched_ref_xy = calibStats{i}.matched_ref_xy;
    metrics.projectors(i).predicted_input_xy = calibStats{i}.predicted_input_xy;
    metrics.projectors(i).detection_time_s = calibStats{i}.detection_time_s;
    metrics.projectors(i).fit_time_s = calibStats{i}.fit_time_s;
    metrics.projectors(i).ablation = calibStats{i}.ablation;
    metrics.projectors(i).cv_ablation = calibStats{i}.cv_ablation;
end
metrics.runtime.projector_calibration_total_s = toc(t_calib_total);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% WARP FINAL IMAGES
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

t_warp_final = tic;
close all
pause(pause_time)
for i = 1:length(all_screen_ids)
    all_im_fin{i} = imwarp( ...
        output_im, ...
        all_tforms{i}, ...
        'OutputView', imref2d(size(Pttrn)));
    all_masks{i} = imresize( ...
        im_mask(:, :, i), ...
        'OutputSize', size(im_tmp, [1 2]), ...
        'Method', 'nearest');
end
metrics.runtime.final_image_warp_total_s = toc(t_warp_final);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% BLENDING
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

t_blending = tic;
w = blendImagesWithMasks( ...
    all_im_fin, ...
    all_masks, ...
    'FeatherPower', w_FeatherPower, ...
    'Priority', w_Priority);
metrics.runtime.blending_weight_generation_s = toc(t_blending);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% PREPARE PROJECTOR WEIGHT MAPS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

t_weight_warp = tic;
for i = 1:length(all_screen_ids)
    w_circ_masked = applyCircularMask( ...
        w{i}, circ_mask_cntr, circ_mask_rad);
    w_warp{i} = imwarp( ...
        w_circ_masked, ...
        all_tforms{i}, ...
        'OutputView', imref2d(size(Pttrn)));
end
metrics.runtime.weight_warp_total_s = toc(t_weight_warp);
%% SIMULATED PHOTOMETRIC UNIFORMITY METRICS IN OVERLAP REGION

if length(w_warp) >= 2
    overlap_mask = true(size(w_warp{1}));

    for i = 1:length(w_warp)
        overlap_mask = overlap_mask & (w_warp{i} > 0.05);
    end

    metrics.photometric.overlap_num_pixels = nnz(overlap_mask);

    % Use the current output image and calibrated projector images to estimate
    % before/after blending in the calibrated image domain.
    unblended_sum = zeros(size(all_im_fin{1}), 'double');
    blended_sum   = zeros(size(all_im_fin{1}), 'double');

    for i = 1:length(all_screen_ids)
        im_i = im2double(all_im_fin{i});

        if size(im_i, 3) == 1
            im_i = repmat(im_i, [1 1 3]);
        end

        unblended_sum = unblended_sum + im_i;
        blended_sum   = blended_sum + im_i .* w_warp{i};
    end

    unblended_sum = min(unblended_sum, 1);
    blended_sum   = min(blended_sum, 1);

    metrics.photometric.before_blending = computePUIFromImage( ...
        unblended_sum, ...
        overlap_mask);

    metrics.photometric.after_blending = computePUIFromImage( ...
        blended_sum, ...
        overlap_mask);

    metrics.photometric.pui_reduction_percent = ...
        100 * (metrics.photometric.before_blending.pui - ...
        metrics.photometric.after_blending.pui) / ...
        max(metrics.photometric.before_blending.pui, eps);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% EXPORT PLAYER CALIBRATION DATA
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

t_lut = tic;
warpLUT = buildWarpLookupTables(all_tforms, size(Pttrn));
metrics.runtime.lut_generation_s = toc(t_lut);
if save_player_calibration
    t_export = tic;

    savePlayerCalibrationData( ...
        player_calibration_dir, ...
        all_screen_ids, ...
        projectors, ...
        [working_img_height working_img_width], ...
        output_content_scale, ...
        output_content_offset, ...
        warpLUT, ...
        w_warp);

    metrics.runtime.export_player_calibration_s = toc(t_export);
end

for i = 1:length(all_screen_ids)
    metrics.projectors(i).native_width = projectors(i).native_width;
    metrics.projectors(i).native_height = projectors(i).native_height;

    metrics.projectors(i).warp_lut_size = size(warpLUT{i}.xIn);
    metrics.projectors(i).weight_map_size = size(w_warp{i});

    metrics.projectors(i).weight_min = min(w_warp{i}(:));
    metrics.projectors(i).weight_max = max(w_warp{i}(:));
    metrics.projectors(i).weight_mean = mean(w_warp{i}(:));
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% DISPLAY IMAGE OR VIDEO
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

switch lower(output_mode)
    case 'image'
        for i = 1:length(all_screen_ids)
            im_out_weighted_i = ...
                double(all_im_fin{i}) .* w_warp{i} / 255;
            displayImageOnScreen( ...
                im_out_weighted_i, ...
                all_screen_ids(i), ...
                final_display_mode);
        end
    case 'video'
        switch lower(video_player_mode)
            case 'imwarp'
                playVideoOnProjectors( ...
                    video_file, ...
                    all_screen_ids, ...
                    all_tforms, ...
                    w_warp, ...
                    Pttrn, ...
                    [working_img_height working_img_width], ...
                    output_content_scale, ...
                    output_content_offset, ...
                    video_frame_step);
            case 'fast_lut'
                playVideoOnProjectorsFast( ...
                    video_file, ...
                    all_screen_ids, ...
                    warpLUT, ...
                    w_warp, ...
                    [working_img_height working_img_width], ...
                    output_content_scale, ...
                    output_content_offset, ...
                    video_frame_step);
            otherwise
                error('Unknown video_player_mode. Use ''imwarp'' or ''fast_lut''.');
        end
    otherwise
        error('Unknown output_mode. Use ''image'' or ''video''.');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% CAPTURED PHOTOMETRIC OVERLAP-EXCESS TEST
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if run_captured_photometric_test && length(all_screen_ids) >= 2

    gray_img = photometric_gray_level * ones( ...
        working_img_height, ...
        working_img_width, ...
        3);

    gray_warped = cell(1, length(all_screen_ids));
    for i = 1:length(all_screen_ids)
        gray_warped{i} = imwarp( ...
            gray_img, ...
            all_tforms{i}, ...
            'OutputView', imref2d(size(Pttrn)));
    end

    mask1 = logical(im_mask(:, :, 1));
    mask2 = logical(im_mask(:, :, 2));
    overlap_mask_camera = mask1 & mask2;

    % Erode boundary pixels to avoid unstable mask-edge regions.
    if nnz(overlap_mask_camera) > 0
        se = strel('disk', 3);
        overlap_mask_camera = imerode(overlap_mask_camera, se);
    end

    metrics.photometric_captured.overlap_num_pixels = nnz(overlap_mask_camera);

    % -----------------------------
    % Capture single-projector references
    % -----------------------------
    single_gray_captures = cell(1, length(all_screen_ids));

    for activeIdx = 1:length(all_screen_ids)
        for i = 1:length(all_screen_ids)
            if i == activeIdx
                displayImageOnScreen( ...
                    gray_warped{i}, ...
                    all_screen_ids(i), ...
                    final_display_mode);
            else
                blackFrame = zeros(projectors(i).native_height, projectors(i).native_width, 3);
                displayImageOnScreen( ...
                    blackFrame, ...
                    all_screen_ids(i), ...
                    final_display_mode);
            end
        end

        pause(pause_time)

        single_gray_captures{activeIdx} = snapshot_multi_cam( ...
            cameras_idx, ...
            cameras_stitching_saved, ...
            cameras_calibration_saved, ...
            camera_crop_rect, ...
            false);

        imwrite( ...
            single_gray_captures{activeIdx}, ...
            fullfile(metrics_dir, sprintf('captured_gray_single_projector_%02d.png', activeIdx)));
    end

    % -----------------------------
    % Case 1: hard/unblended display
    % -----------------------------
    for i = 1:length(all_screen_ids)
        displayImageOnScreen( ...
            gray_warped{i}, ...
            all_screen_ids(i), ...
            final_display_mode);
    end

    pause(pause_time)

    im_gray_before = snapshot_multi_cam( ...
        cameras_idx, ...
        cameras_stitching_saved, ...
        cameras_calibration_saved, ...
        camera_crop_rect, ...
        false);

    imwrite(im_gray_before, fullfile(metrics_dir, 'captured_gray_before_blending.png'));

    % -----------------------------
    % Case 2: soft blended display
    % -----------------------------
    for i = 1:length(all_screen_ids)
        gray_weighted_i = gray_warped{i} .* w_warp{i};

        displayImageOnScreen( ...
            gray_weighted_i, ...
            all_screen_ids(i), ...
            final_display_mode);
    end

    pause(pause_time)

    im_gray_after = snapshot_multi_cam( ...
        cameras_idx, ...
        cameras_stitching_saved, ...
        cameras_calibration_saved, ...
        camera_crop_rect, ...
        false);

    imwrite(im_gray_after, fullfile(metrics_dir, 'captured_gray_after_blending.png'));

    % -----------------------------
    % Compute overlap-excess metric
    % -----------------------------
    metrics.photometric_captured = computeOverlapExcessMetric( ...
        single_gray_captures{1}, ...
        single_gray_captures{2}, ...
        im_gray_before, ...
        im_gray_after, ...
        overlap_mask_camera);

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% FINAL SNAPSHOT
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

pause(pause_time)
im = snapshot_multi_cam( ...
    cameras_idx, ...
    cameras_stitching_saved, ...
    cameras_calibration_saved, ...
    camera_crop_rect);
imshow_scr_idx(im, monitor_id)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% SAVE METRICS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if save_metrics
    metrics_file_mat = fullfile(metrics_dir, sprintf('calibration_metrics_run_%02d.mat', run_id));
    metrics_file_json = fullfile(metrics_dir, sprintf('calibration_metrics_run_%02d.json', run_id));
    save(metrics_file_mat, 'metrics');

    metrics_json_ready = removeLargeMetricFields(metrics);
    jsonText = jsonencode(metrics_json_ready, 'PrettyPrint', true);

    fid = fopen(metrics_file_json, 'w');
    if fid < 0
        error('Could not create metrics JSON file.');
    end
    fprintf(fid, '%s', jsonText);
    fclose(fid);

    fprintf('Calibration metrics saved to: %s\n', metrics_dir);
end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% LOCAL FUNCTIONS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function multi_cam_im = snapshot_multi_cam(cameras_idx, cameras_stitching, cameras_calibration, crop_mask, apply_equalization)
%SNAPSHOT_MULTI_CAM Captures, corrects, stitches, calibrates, and crops images from selected cameras.
%   multi_cam_im = snapshot_multi_cam(cameras_idx, cameras_stitching, cameras_calibration, crop_mask)
%   captures images from the cameras listed in cameras_idx, applies image
%   flipping and brightness equalization, stitches multiple camera views when
%   needed, applies the saved camera calibration transform, and returns the
%   cropped multi-camera image.
if nargin < 5
    apply_equalization = true;
end
for i = 1:length(cameras_idx)
    tmp_im = snapshot(webcam(cameras_idx(i))); %#ok<*AGROW>
    tmp_im = fliplr(flipud(tmp_im)); %#ok<*FLUDLR>

    if apply_equalization
        tmp_im = equalizeColorBrightness(tmp_im);
    end

    NonStichedImages{i} = tmp_im;
end
stitched_im = NonStichedImages{1};
for i = 2:size(NonStichedImages, 2)
    stitched_im = apply_stitching_2_images_mfile(stitched_im, NonStichedImages{i}, cameras_stitching{i-1});
end
im = imwarp(stitched_im, cameras_calibration{1}, 'OutputView', imref2d(size(stitched_im)));
multi_cam_im = imcrop(im, crop_mask);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function One_Scr_On_others_Off(all_screen_ids, screen_idx, projectors, display_mode)
%ONE_SCR_ON_OTHERS_OFF Displays white on one selected projector and black on all others.
%   One_Scr_On_others_Off(all_screen_ids, screen_idx, projectors, display_mode)
%   creates full-screen white and black images based on the native resolution
%   of each projector. The projector specified by screen_idx is turned on
%   with a white image, while all other projectors are turned off with a
%   black image.
for i = 1:length(all_screen_ids)
    h = projectors(i).native_height;
    w = projectors(i).native_width;
    if all_screen_ids(i) == screen_idx
        img = uint8(255 * ones(h, w));
    else
        img = uint8(zeros(h, w));
    end
    displayImageOnScreen(img, all_screen_ids(i), display_mode);
end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function imshow_scr_idx(img, screenIndex)
%IMSHOW_SCR_IDX Displays an image on the selected monitor for debugging.
%   imshow_scr_idx(img, screenIndex) opens a normal MATLAB figure centered
%   on the selected monitor. Unlike projector display functions, this viewer
%   keeps zoom and pan enabled for inspection.
if isempty(img) || ~isnumeric(img)
    error('The input must be a valid image array.');
end
monitors = get(0, 'MonitorPositions');
numMonitors = size(monitors, 1);
if nargin < 2 || screenIndex < 1 || screenIndex > numMonitors
    screenIndex = 1;
end
monitorPosition = monitors(screenIndex, :);
monitorLeft = monitorPosition(1);
monitorBottom = monitorPosition(2);
monitorWidth = monitorPosition(3);
monitorHeight = monitorPosition(4);
[imgHeight, imgWidth, ~] = size(img);
xOffset = monitorLeft + (monitorWidth - imgWidth) / 2;
yOffset = monitorBottom + (monitorHeight - imgHeight) / 2;
figurePosition = [xOffset, yOffset, imgWidth, imgHeight];
figureHandle = figure('Name', 'Image Display', ...
    'NumberTitle', 'off', ...
    'MenuBar', 'none', ...
    'ToolBar', 'none', ...
    'Units', 'pixels', ...
    'Position', figurePosition, ...
    'Resize', 'on', ...
    'WindowStyle', 'normal'); %#ok<NASGU>
imshow(img, 'InitialMagnification', 100);
zoom on;
pan on;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function adjustedRGB = equalizeColorBrightness(rgbImg, targetMean)
%EQUALIZECOLORBRIGHTNESS Adjusts image brightness to a target mean value.
%   adjustedRGB = equalizeColorBrightness(rgbImg, targetMean) adjusts the
%   Value channel in HSV color space so that its mean approaches targetMean.
%   If targetMean is not provided, 0.5 is used.
if nargin < 2
    targetMean = 0.5;
end
hsvImg = rgb2hsv(rgbImg);
V = hsvImg(:,:,3);
currentMean = mean(V(:));
delta = targetMean - currentMean;
V = V + delta;
V = min(max(V, 0), 1);
hsvImg(:,:,3) = V;
adjustedRGB = hsv2rgb(hsvImg);
adjustedRGB = im2uint8(adjustedRGB);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function closeFiguresOnScreen(screenIndex)
%CLOSEFIGURESONSCREEN Closes all open MATLAB figures located on a selected monitor.
%   closeFiguresOnScreen(screenIndex) finds figures whose lower-left corner
%   lies inside the selected monitor area and closes them.
monitors = get(0, 'MonitorPositions');
numMonitors = size(monitors, 1);
if screenIndex < 1 || screenIndex > numMonitors
    error('Invalid screen index. Choose a valid monitor.');
end
monitorPosition = monitors(screenIndex, :);
monitorLeft = monitorPosition(1);
monitorBottom = monitorPosition(2);
monitorWidth = monitorPosition(3);
monitorHeight = monitorPosition(4);
allFigures = findobj('Type', 'figure');
for i = 1:length(allFigures)
    figHandle = allFigures(i);
    figPosition = get(figHandle, 'Position');
    figLeft = figPosition(1);
    figBottom = figPosition(2);
    if (figLeft >= monitorLeft) && (figLeft < monitorLeft + monitorWidth) && ...
            (figBottom >= monitorBottom) && (figBottom < monitorBottom + monitorHeight)
        close(figHandle);
    end
end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function weightMaps = blendImagesWithMasks(images, masks, varargin)
%BLENDIMAGESWITHMASKS Computes soft blending weight maps from projector masks.
%   weightMaps = blendImagesWithMasks(images, masks, 'FeatherPower', p, 'Priority', q)
%   creates one normalized weight map for each projector. The weights are
%   based on distance from mask boundaries, optionally adjusted by feather
%   power and projector priority.
p = inputParser;
addParameter(p, 'FeatherPower', 1);
addParameter(p, 'Priority', []);
parse(p, varargin{:});
featherPower = p.Results.FeatherPower;
priority = p.Results.Priority;
N = numel(images);
if isempty(priority)
    priority = ones(1, N);
end
for i = 1:N
    img = im2double(images{i});
    if size(img, 3) == 1
        img = repmat(img, [1 1 3]);
    end
    images{i} = img;
    masks{i} = logical(masks{i});
end
distances = cell(1, N);
for i = 1:N
    d = bwdist(~masks{i});
    d = d .^ featherPower;
    d = d * priority(i);
    distances{i} = d;
end
distanceSum = eps;
for i = 1:N
    distanceSum = distanceSum + distances{i};
end
weightMaps = cell(1, N);
for i = 1:N
    weightMaps{i} = distances{i} ./ distanceSum;
end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function masked_img = applyCircularMask(img, center, radius)
%APPLYCIRCULARMASK Applies a circular region mask to a 2D image.
%   masked_img = applyCircularMask(img, center, radius) keeps pixels inside
%   the circle defined by center = [x y] and radius, and sets all pixels
%   outside the circle to zero.
if ndims(img) ~= 2
    error('Input image must be a 2D grayscale image.');
end
if ~isvector(center) || numel(center) ~= 2
    error('Center must be a 2-element vector [x y].');
end
if ~isscalar(radius) || radius <= 0
    error('Radius must be a positive scalar.');
end
[rows, cols] = size(img);
[x, y] = meshgrid(1:cols, 1:rows);
mask = (x - center(1)).^2 + (y - center(2)).^2 <= radius^2;
masked_img = img;
masked_img(~mask) = 0;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function stitched_im = apply_stitching_2_images_mfile(im1, im2, cameras_calibration)
%APPLY_STITCHING_2_IMAGES_MFILE Stitches two camera images using saved calibration data.
%   stitched_im = apply_stitching_2_images_mfile(im1, im2, cameras_calibration)
%   warps the second image into the common stitched view, maps the first
%   image to the same output view, and blends both images using saved weight
%   maps.
tform = cameras_calibration{1};
expandedOutputView = cameras_calibration{2};
weight1 = cameras_calibration{3};
weight2 = cameras_calibration{4};
algnd_im2 = imwarp(im2, tform, 'OutputView', expandedOutputView);
im1_resized = imwarp(im1, affine2d(eye(3)), 'OutputView', expandedOutputView);
im1_resized = im2double(im1_resized);
algnd_im2 = im2double(algnd_im2);
stitched_im = weight1 .* im1_resized + weight2 .* algnd_im2;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [Calibrated_Image, tform, stats] = Calibration_AprilTags(Pattern, image)
%CALIBRATION_APRILTAGS Estimates the geometric transform using matched AprilTags.
%   [Calibrated_Image, tform, stats] = Calibration_AprilTags(Pattern, image)
%   detects AprilTags in the projected pattern and the camera image, matches
%   them by tag ID, estimates a third-degree polynomial transform, and
%   returns geometric error statistics, polynomial-degree ablation results,
%   and cross-validation results.

input_image = image;
original_tags_image = Pattern;


%% APRILTAG DETECTION


t_detect = tic;

[ids_input, locs_input] = readAprilTag(input_image, 'tag36h11');
[ids_ref, locs_ref] = readAprilTag(original_tags_image, 'tag36h11');

detection_time_s = toc(t_detect);

if isempty(ids_input) || isempty(ids_ref)
    error('No AprilTags were detected in the input image or reference pattern.');
end

input_tags_xy = squeeze(mean(locs_input));
ref_tags_xy   = squeeze(mean(locs_ref));

% Make sure the arrays are 2-by-N even if MATLAB squeezes dimensions.
if size(input_tags_xy, 1) ~= 2
    input_tags_xy = input_tags_xy';
end

if size(ref_tags_xy, 1) ~= 2
    ref_tags_xy = ref_tags_xy';
end


%% TAG MATCHING BY ID


[~, matched_input_ids] = ismember(ids_input, ids_ref);
valid_matches = matched_input_ids > 0;

matched_input_tags_xy = input_tags_xy(:, valid_matches);
matched_ref_tags_xy   = ref_tags_xy(:, matched_input_ids(valid_matches));

num_matched_tags = size(matched_input_tags_xy, 2);

if num_matched_tags < 10
    error( ...
        'At least 10 matched tags are required for a third-degree polynomial transformation. Only %d were found.', ...
        num_matched_tags);
end


%% POLYNOMIAL DEGREE ABLATION


ablation_degrees = [2 3 4];
ablation = struct([]);

for dd = 1:numel(ablation_degrees)

    degree = ablation_degrees(dd);
    min_points_required = (degree + 1) * (degree + 2) / 2;

    ablation(dd).degree = degree;
    ablation(dd).min_points_required = min_points_required;
    ablation(dd).num_matched_tags = num_matched_tags;

    if num_matched_tags < min_points_required

        ablation(dd).valid = false;
        ablation(dd).failure_reason = sprintf( ...
            'Insufficient matched tags: %d available, %d required.', ...
            num_matched_tags, ...
            min_points_required);

        ablation(dd).rms_error_px = NaN;
        ablation(dd).mean_error_px = NaN;
        ablation(dd).median_error_px = NaN;
        ablation(dd).max_error_px = NaN;
        ablation(dd).p95_error_px = NaN;
        ablation(dd).fit_time_s = NaN;

        continue

    end

    try

        t_fit_ablation = tic;

        tform_tmp = fitgeotrans( ...
            matched_input_tags_xy', ...
            matched_ref_tags_xy', ...
            "polynomial", ...
            degree);

        ablation(dd).fit_time_s = toc(t_fit_ablation);

        [pred_x_tmp, pred_y_tmp] = transformPointsInverse( ...
            tform_tmp, ...
            matched_ref_tags_xy(1, :)', ...
            matched_ref_tags_xy(2, :)');

        pred_xy_tmp  = [pred_x_tmp pred_y_tmp];
        input_xy_tmp = matched_input_tags_xy';

        err_tmp = sqrt(sum((pred_xy_tmp - input_xy_tmp).^2, 2));

        ablation(dd).valid = true;
        ablation(dd).failure_reason = '';
        ablation(dd).rms_error_px = sqrt(mean(err_tmp.^2));
        ablation(dd).mean_error_px = mean(err_tmp);
        ablation(dd).median_error_px = median(err_tmp);
        ablation(dd).max_error_px = max(err_tmp);
        ablation(dd).p95_error_px = prctile(err_tmp, 95);

    catch ME

        ablation(dd).valid = false;
        ablation(dd).failure_reason = ME.message;
        ablation(dd).rms_error_px = NaN;
        ablation(dd).mean_error_px = NaN;
        ablation(dd).median_error_px = NaN;
        ablation(dd).max_error_px = NaN;
        ablation(dd).p95_error_px = NaN;
        ablation(dd).fit_time_s = NaN;

    end

end


%% CROSS-VALIDATION ABLATION


cv_ablation = computePolynomialDegreeCrossValidation( ...
    matched_input_tags_xy', ...
    matched_ref_tags_xy', ...
    ablation_degrees, ...
    5);


%% MAIN THIRD-DEGREE CALIBRATION


t_fit = tic;

tform = fitgeotrans( ...
    matched_input_tags_xy', ...
    matched_ref_tags_xy', ...
    "polynomial", ...
    3);

fit_time_s = toc(t_fit);

Calibrated_Image = imwarp( ...
    input_image, ...
    tform, ...
    'OutputView', imref2d(size(input_image)));


%% MAIN FITTING RESIDUAL


% Compute fitting residual using inverse point mapping.
% This is consistent with the inverse lookup-table generation used later.
[pred_x, pred_y] = transformPointsInverse( ...
    tform, ...
    matched_ref_tags_xy(1, :)', ...
    matched_ref_tags_xy(2, :)');

pred_xy  = [pred_x pred_y];
input_xy = matched_input_tags_xy';

err_vec = sqrt(sum((pred_xy - input_xy).^2, 2));


%% OUTPUT STATISTICS


stats = struct();

stats.num_detected_input_tags = numel(ids_input);
stats.num_detected_ref_tags = numel(ids_ref);
stats.num_matched_tags = num_matched_tags;

stats.rms_error_px = sqrt(mean(err_vec.^2));
stats.mean_error_px = mean(err_vec);
stats.median_error_px = median(err_vec);
stats.max_error_px = max(err_vec);
stats.p95_error_px = prctile(err_vec, 95);

stats.detection_time_s = detection_time_s;
stats.fit_time_s = fit_time_s;

stats.error_vector_px = err_vec;
stats.matched_input_xy = matched_input_tags_xy';
stats.matched_ref_xy = matched_ref_tags_xy';
stats.predicted_input_xy = pred_xy;

stats.ablation = ablation;
stats.cv_ablation = cv_ablation;

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function out = prepareOutputImageAutoFit(img, targetSize, contentScale, contentOffset)
%PREPAREOUTPUTIMAGEAUTOFIT Fits an output image into the projector working canvas.
%   out = prepareOutputImageAutoFit(img, targetSize, contentScale, contentOffset)
%   resizes the input image while preserving its aspect ratio, applies an
%   additional scale factor, and places it on the target canvas using the
%   specified pixel offset.
if nargin < 3 || isempty(contentScale)
    contentScale = 1.0;
end
if nargin < 4 || isempty(contentOffset)
    contentOffset = [0 0];
end
if contentScale <= 0
    error('contentScale must be a positive scalar.');
end
if ~isvector(contentOffset) || numel(contentOffset) ~= 2
    error('contentOffset must be a 2-element vector [x y].');
end
if isempty(img) || ~isnumeric(img)
    error('Input image must be a valid numeric image.');
end
targetHeight = targetSize(1);
targetWidth = targetSize(2);
offsetX = round(contentOffset(1));
offsetY = round(contentOffset(2));
imgHeight = size(img, 1);
imgWidth = size(img, 2);
baseScale = min(targetHeight / imgHeight, targetWidth / imgWidth);
scale = baseScale * contentScale;
newHeight = max(1, round(imgHeight * scale));
newWidth = max(1, round(imgWidth * scale));
resizedImg = imresize(img, [newHeight newWidth]);
out = placeImageOnCanvasWithOffset(resizedImg, [targetHeight targetWidth], class(img), [offsetX offsetY]);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function canvas = placeImageOnCanvasWithOffset(img, targetSize, imgClass, contentOffset)
%PLACEIMAGEONCANVASWITHOFFSET Places an image on a centered canvas with pixel offset.
%   canvas = placeImageOnCanvasWithOffset(img, targetSize, imgClass, contentOffset)
%   creates a target-size canvas, places img at the center shifted by
%   contentOffset = [x y], and clips the image if it extends beyond the
%   canvas boundaries.
targetHeight = targetSize(1);
targetWidth = targetSize(2);
imgHeight = size(img, 1);
imgWidth = size(img, 2);
offsetX = round(contentOffset(1));
offsetY = round(contentOffset(2));
if ismatrix(img)
    numChannels = 1;
else
    numChannels = size(img, 3);
end
if isinteger(img)
    canvas = zeros(targetHeight, targetWidth, numChannels, imgClass);
else
    canvas = zeros(targetHeight, targetWidth, numChannels, 'like', img);
end
centerRowStart = floor((targetHeight - imgHeight) / 2) + 1;
centerColStart = floor((targetWidth - imgWidth) / 2) + 1;
targetRowStart = centerRowStart + offsetY;
targetColStart = centerColStart + offsetX;
targetRowEnd = targetRowStart + imgHeight - 1;
targetColEnd = targetColStart + imgWidth - 1;
visibleTargetRowStart = max(1, targetRowStart);
visibleTargetColStart = max(1, targetColStart);
visibleTargetRowEnd = min(targetHeight, targetRowEnd);
visibleTargetColEnd = min(targetWidth, targetColEnd);
if visibleTargetRowStart > visibleTargetRowEnd || visibleTargetColStart > visibleTargetColEnd
    return
end
sourceRowStart = visibleTargetRowStart - targetRowStart + 1;
sourceColStart = visibleTargetColStart - targetColStart + 1;
sourceRowEnd = sourceRowStart + (visibleTargetRowEnd - visibleTargetRowStart);
sourceColEnd = sourceColStart + (visibleTargetColEnd - visibleTargetColStart);
if numChannels == 1
    canvas(visibleTargetRowStart:visibleTargetRowEnd, visibleTargetColStart:visibleTargetColEnd, 1) = img(sourceRowStart:sourceRowEnd, sourceColStart:sourceColEnd);
    canvas = canvas(:, :, 1);
else
    canvas(visibleTargetRowStart:visibleTargetRowEnd, visibleTargetColStart:visibleTargetColEnd, :) = img(sourceRowStart:sourceRowEnd, sourceColStart:sourceColEnd, :);
end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function projectors = getProjectorDisplayInfo(all_screen_ids)
%GETPROJECTORDISPLAYINFO Reads native display information for selected projectors.
%   projectors = getProjectorDisplayInfo(all_screen_ids) uses MATLAB monitor
%   positions to build a structure containing the screen ID, native size, and
%   working image size for each selected projector.
monitors = get(0, 'MonitorPositions');
numProjectors = numel(all_screen_ids);
projectors = struct( ...
    'screen_id', [], ...
    'native_width', [], ...
    'native_height', [], ...
    'working_width', [], ...
    'working_height', [], ...
    'image_size', []);
for i = 1:numProjectors
    screenId = all_screen_ids(i);
    if screenId < 1 || screenId > size(monitors, 1)
        error('Invalid projector screen ID: %d', screenId);
    end
    nativeWidth = monitors(screenId, 3);
    nativeHeight = monitors(screenId, 4);
    projectors(i).screen_id = screenId;
    projectors(i).native_width = nativeWidth;
    projectors(i).native_height = nativeHeight;
    projectors(i).working_width = nativeWidth;
    projectors(i).working_height = nativeHeight;
    projectors(i).image_size = [nativeHeight nativeWidth];
end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function figureHandle = displayImageOnScreen(img, screenIndex, mode, fh)
%DISPLAYIMAGEONSCREEN Displays an image on a selected monitor in exact mode.
%   figureHandle = displayImageOnScreen(img, screenIndex, mode, fh) opens or
%   updates a borderless fullscreen figure on the selected monitor. Only
%   exact display mode is currently supported. If the image is larger than
%   the monitor, it is auto-fitted before display.
if nargin < 3 || isempty(mode)
    mode = 'exact';
end
if isempty(img) || ~isnumeric(img)
    error('The input must be a valid image array.');
end
if ~strcmpi(mode, 'exact')
    error('Only ''exact'' display mode is currently supported.');
end
monitors = get(0, 'MonitorPositions');
numMonitors = size(monitors, 1);
if nargin < 2 || screenIndex < 1 || screenIndex > numMonitors
    screenIndex = 1;
end
monitorPosition = monitors(screenIndex, :);
monitorLeft = monitorPosition(1);
monitorBottom = monitorPosition(2);
monitorWidth = monitorPosition(3);
monitorHeight = monitorPosition(4);
[imgHeight, imgWidth, ~] = size(img);
if imgWidth > monitorWidth || imgHeight > monitorHeight
    img = prepareOutputImageAutoFit(img, [monitorHeight monitorWidth], 1.0, [0 0]);
    [imgHeight, imgWidth, ~] = size(img);
end
xOffset = monitorLeft + floor((monitorWidth - imgWidth) / 2);
yOffset = monitorBottom + floor((monitorHeight - imgHeight) / 2);
figurePosition = [xOffset, yOffset, imgWidth, imgHeight];
if nargin < 4 || isempty(fh)
    figureHandle = figure('Name', 'Image Display', ...
        'NumberTitle', 'off', ...
        'MenuBar', 'none', ...
        'ToolBar', 'none', ...
        'Units', 'pixels', ...
        'Position', figurePosition, ...
        'WindowStyle', 'normal', ...
        'WindowState', 'fullscreen');
else
    figureHandle = fh;
    set(figureHandle, 'Position', figurePosition);
    clf(figureHandle);
end
axesHandle = axes('Parent', figureHandle, 'Units', 'pixels', 'Position', [0 0 imgWidth imgHeight]);
imshow(img, 'InitialMagnification', 100, 'Parent', axesHandle);
axis(axesHandle, 'image');
axis(axesHandle, 'off');
zoom(figureHandle, 'off');
pan(figureHandle, 'off');
set(figureHandle, 'WindowButtonDownFcn', '', ...
    'WindowButtonMotionFcn', '', ...
    'WindowScrollWheelFcn', '');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function playVideoOnProjectorsFast(video_file, all_screen_ids, warpLUT, w_warp, targetSize, contentScale, contentOffset, frameStep)
%PLAYVIDEOONPROJECTORSFAST Plays video using precomputed warp lookup tables.
if nargin < 8 || isempty(frameStep)
    frameStep = 1;
end
videoReader = VideoReader(video_file);
numProjectors = length(all_screen_ids);
figHandles = gobjects(1, numProjectors);
imgHandles = gobjects(1, numProjectors);
isFirstDisplayedFrame = true;
frameCounter = 0;
while hasFrame(videoReader)
    frameCounter = frameCounter + 1;
    frameRaw = readFrame(videoReader);
    if mod(frameCounter - 1, frameStep) ~= 0
        continue
    end
    framePrepared = prepareOutputImageAutoFit(frameRaw, targetSize, contentScale, contentOffset);
    for i = 1:numProjectors
        frameWarped = applyWarpLookup(framePrepared, warpLUT{i});
        frameWeighted = frameWarped .* w_warp{i};
        if isFirstDisplayedFrame
            [figHandles(i), imgHandles(i)] = initializeProjectorVideoWindow(frameWeighted, all_screen_ids(i));
        else
            set(imgHandles(i), 'CData', frameWeighted);
        end
    end
    drawnow limitrate nocallbacks
    isFirstDisplayedFrame = false;
end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [figureHandle, imageHandle] = initializeProjectorVideoWindow(img, screenIndex)
%INITIALIZEPROJECTORVIDEOWINDOW Creates a fullscreen image window for video playback.
%   The returned image handle is updated during playback to avoid reopening
%   MATLAB figures for every video frame.
monitors = get(0, 'MonitorPositions');
numMonitors = size(monitors, 1);
if screenIndex < 1 || screenIndex > numMonitors
    screenIndex = 1;
end
monitorPosition = monitors(screenIndex, :);
monitorLeft = monitorPosition(1);
monitorBottom = monitorPosition(2);
monitorWidth = monitorPosition(3);
monitorHeight = monitorPosition(4);
figurePosition = [monitorLeft, monitorBottom, monitorWidth, monitorHeight];
figureHandle = figure('Name', 'Projector Video Display', ...
    'NumberTitle', 'off', ...
    'MenuBar', 'none', ...
    'ToolBar', 'none', ...
    'Units', 'pixels', ...
    'Position', figurePosition, ...
    'WindowStyle', 'normal', ...
    'WindowState', 'fullscreen');
axesHandle = axes('Parent', figureHandle, ...
    'Units', 'pixels', ...
    'Position', [0 0 monitorWidth monitorHeight]);
imageHandle = imshow(img, 'InitialMagnification', 100, 'Parent', axesHandle);
axis(axesHandle, 'image');
axis(axesHandle, 'off');
zoom(figureHandle, 'off');
pan(figureHandle, 'off');
set(figureHandle, 'WindowButtonDownFcn', '', ...
    'WindowButtonMotionFcn', '', ...
    'WindowScrollWheelFcn', '');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function warpLUT = buildWarpLookupTables(all_tforms, outputSize)
%BUILDWARPLOOKUPTABLES Builds inverse coordinate maps for repeated video warping.
numProjectors = numel(all_tforms);
[outputHeight, outputWidth, ~] = sizeFromImageSize(outputSize);
[xOut, yOut] = meshgrid(1:outputWidth, 1:outputHeight);
warpLUT = cell(1, numProjectors);
for i = 1:numProjectors
    [xIn, yIn] = transformPointsInverse(all_tforms{i}, xOut, yOut);
    warpLUT{i}.xIn = single(xIn);
    warpLUT{i}.yIn = single(yIn);
    warpLUT{i}.outputSize = [outputHeight outputWidth];
end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [h, w, c] = sizeFromImageSize(sz)
h = sz(1);
w = sz(2);
if numel(sz) >= 3
    c = sz(3);
else
    c = 1;
end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function warped = applyWarpLookup(frame, lut)
%APPLYWARPLOOKUP Warps an image using a precomputed inverse coordinate map.
frame = im2double(frame);
outputHeight = lut.outputSize(1);
outputWidth = lut.outputSize(2);
if ismatrix(frame)
    warped = interp2(frame, double(lut.xIn), double(lut.yIn), 'linear', 0);
else
    numChannels = size(frame, 3);
    warped = zeros(outputHeight, outputWidth, numChannels);
    for ch = 1:numChannels
        warped(:,:,ch) = interp2(frame(:,:,ch), double(lut.xIn), double(lut.yIn), 'linear', 0);
    end
end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function playVideoOnProjectors(video_file, all_screen_ids, all_tforms, w_warp, Pttrn, targetSize, contentScale, contentOffset, frameStep)
%PLAYVIDEOONPROJECTORS Plays a video through the calibrated multi-projector system.
%   Each displayed frame is fitted to the working canvas, warped for each
%   projector, weighted by the precomputed blending maps, and shown on the
%   corresponding projector.
if nargin < 9 || isempty(frameStep)
    frameStep = 1;
end
if frameStep < 1
    error('frameStep must be a positive integer.');
end
videoReader = VideoReader(video_file);
numProjectors = length(all_screen_ids);
outputRef = imref2d(size(Pttrn));
figHandles = gobjects(1, numProjectors);
imgHandles = gobjects(1, numProjectors);
isFirstDisplayedFrame = true;
frameCounter = 0;
while hasFrame(videoReader)
    frameCounter = frameCounter + 1;
    frameRaw = readFrame(videoReader);
    if mod(frameCounter - 1, frameStep) ~= 0
        continue
    end
    framePrepared = prepareOutputImageAutoFit(frameRaw, targetSize, contentScale, contentOffset);
    framePrepared = im2double(framePrepared);
    for i = 1:numProjectors
        frameWarped = imwarp( ...
            framePrepared, ...
            all_tforms{i}, ...
            'OutputView', outputRef);
        frameWeighted = frameWarped .* w_warp{i};
        if isFirstDisplayedFrame
            [figHandles(i), imgHandles(i)] = initializeProjectorVideoWindow( ...
                frameWeighted, ...
                all_screen_ids(i));
        else
            set(imgHandles(i), 'CData', frameWeighted);
        end
    end
    drawnow limitrate nocallbacks
    isFirstDisplayedFrame = false;
end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function savePlayerCalibrationData(outputDir, all_screen_ids, projectors, workingSize, contentScale, contentOffset, warpLUT, w_warp)
%SAVEPLAYERCALIBRATIONDATA Exports calibration data for an external video player.
%   The metadata is saved as JSON, while large numeric maps are saved as CSV
%   files for easier use in external players.
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end
numProjectors = numel(all_screen_ids);
metadata = struct();
metadata.version = '1.0';
metadata.created_at = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
metadata.working_size = workingSize;
metadata.content_scale = contentScale;
metadata.content_offset = contentOffset;
metadata.interpolation = 'linear';
metadata.out_of_bounds_value = 0;
metadata.num_projectors = numProjectors;
metadata.projectors = struct([]);
for i = 1:numProjectors
    xFile = sprintf('projector_%02d_xIn.csv', i);
    yFile = sprintf('projector_%02d_yIn.csv', i);
    wFile = sprintf('projector_%02d_weight.csv', i);
    writematrix(warpLUT{i}.xIn, fullfile(outputDir, xFile));
    writematrix(warpLUT{i}.yIn, fullfile(outputDir, yFile));
    writematrix(w_warp{i}, fullfile(outputDir, wFile));
    metadata.projectors(i).index = i;
    metadata.projectors(i).screen_id = all_screen_ids(i);
    metadata.projectors(i).native_width = projectors(i).native_width;
    metadata.projectors(i).native_height = projectors(i).native_height;
    metadata.projectors(i).image_size = projectors(i).image_size;
    metadata.projectors(i).xIn_csv = xFile;
    metadata.projectors(i).yIn_csv = yFile;
    metadata.projectors(i).weight_csv = wFile;
end
jsonText = jsonencode(metadata, 'PrettyPrint', true);
fid = fopen(fullfile(outputDir, 'calibration_metadata.json'), 'w');
if fid < 0
    error('Could not create calibration metadata file.');
end
fprintf(fid, '%s', jsonText);
fclose(fid);
fprintf('Player calibration data saved to: %s\n', outputDir);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function puiStats = computePUIFromImage(img, roiMask)
%COMPUTEPUIFROMIMAGE Computes luminance uniformity statistics inside an ROI.
%   puiStats = computePUIFromImage(img, roiMask) computes mean luminance,
%   standard deviation, and PUI = sigma/mu inside the selected ROI.

if isa(img, 'uint8')
    img = im2double(img);
else
    img = double(img);
    if max(img(:)) > 1
        img = img / 255;
    end
end

if size(img, 3) == 3
    L = 0.2126 * img(:,:,1) + 0.7152 * img(:,:,2) + 0.0722 * img(:,:,3);
else
    L = img;
end

roiMask = logical(roiMask);

values = L(roiMask);
values = values(isfinite(values));

puiStats = struct();
puiStats.mean_luminance = mean(values);
puiStats.std_luminance = std(values);
puiStats.pui = puiStats.std_luminance / max(puiStats.mean_luminance, eps);
puiStats.num_pixels = numel(values);

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function out = removeLargeMetricFields(in)
%REMOVELARGEMETRICFIELDS Removes large arrays before JSON export.

out = in;

largeFields = { ...
    'error_vector_px', ...
    'matched_input_xy', ...
    'predicted_input_xy', ...
    'predicted_ref_xy'};

if isfield(out, 'projectors') && ~isempty(out.projectors)
    for k = 1:numel(largeFields)
        fieldName = largeFields{k};

        if isfield(out.projectors, fieldName)
            out.projectors = rmfield(out.projectors, fieldName);
        end
    end
end

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function stats = computeOverlapExcessMetric(single1, single2, beforeImg, afterImg, overlapMask)
%COMPUTEOVERLAPEXCESSMETRIC Measures overlap brightness excess before/after blending.
%   The target luminance in the overlap is estimated from the brighter
%   single-projector response at each pixel. Hard overlap is expected to be
%   over-bright, while blended overlap should move closer to this target.

L1 = getLuminanceImage(single1);
L2 = getLuminanceImage(single2);
Lb = getLuminanceImage(beforeImg);
La = getLuminanceImage(afterImg);

overlapMask = logical(overlapMask);

target = max(L1, L2);

target_v = target(overlapMask);
before_v = Lb(overlapMask);
after_v  = La(overlapMask);

valid = isfinite(target_v) & isfinite(before_v) & isfinite(after_v) & target_v > 0.02;

target_v = target_v(valid);
before_v = before_v(valid);
after_v  = after_v(valid);

before_abs_err = abs(before_v - target_v);
after_abs_err  = abs(after_v - target_v);

before_rmse = sqrt(mean((before_v - target_v).^2));
after_rmse  = sqrt(mean((after_v - target_v).^2));

stats = struct();

stats.num_pixels = numel(target_v);

stats.target_mean = mean(target_v);
stats.before_mean = mean(before_v);
stats.after_mean = mean(after_v);

stats.before_mae = mean(before_abs_err);
stats.after_mae = mean(after_abs_err);

stats.before_rmse = before_rmse;
stats.after_rmse = after_rmse;

stats.before_relative_mae = stats.before_mae / max(stats.target_mean, eps);
stats.after_relative_mae = stats.after_mae / max(stats.target_mean, eps);

stats.mae_reduction_percent = ...
    100 * (stats.before_mae - stats.after_mae) / max(stats.before_mae, eps);

stats.rmse_reduction_percent = ...
    100 * (stats.before_rmse - stats.after_rmse) / max(stats.before_rmse, eps);

stats.before_excess_ratio = mean(before_v ./ max(target_v, eps));
stats.after_excess_ratio = mean(after_v ./ max(target_v, eps));

stats.excess_ratio_reduction_percent = ...
    100 * (stats.before_excess_ratio - stats.after_excess_ratio) / ...
    max(stats.before_excess_ratio - 1, eps);

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function L = getLuminanceImage(img)
%GETLUMINANCEIMAGE Converts an RGB or grayscale image to normalized luminance.

if isa(img, 'uint8')
    img = im2double(img);
else
    img = double(img);
    if max(img(:)) > 1
        img = img / 255;
    end
end

if size(img, 3) == 3
    L = 0.2126 * img(:,:,1) + 0.7152 * img(:,:,2) + 0.0722 * img(:,:,3);
else
    L = img;
end

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function cvResults = computePolynomialDegreeCrossValidation(input_xy, ref_xy, degrees, numFolds)
%COMPUTEPOLYNOMIALDEGREECROSSVALIDATION Evaluates polynomial degree by K-fold validation.
%   input_xy and ref_xy are N-by-2 matched point arrays.

N = size(input_xy, 1);

rng(1);
order = randperm(N);

foldId = zeros(N, 1);
for i = 1:N
    foldId(order(i)) = mod(i-1, numFolds) + 1;
end

cvResults = struct([]);

for dd = 1:numel(degrees)

    degree = degrees(dd);
    min_points_required = (degree + 1) * (degree + 2) / 2;

    allErr = [];
    validDegree = true;
    failureReason = '';

    cvResults(dd).degree = degree;
    cvResults(dd).min_points_required = min_points_required;
    cvResults(dd).num_points = N;

    for fold = 1:numFolds

        testIdx = foldId == fold;
        trainIdx = ~testIdx;

        if nnz(trainIdx) < min_points_required

            validDegree = false;
            failureReason = sprintf( ...
                'Fold %d has insufficient training points: %d available, %d required.', ...
                fold, ...
                nnz(trainIdx), ...
                min_points_required);

            break

        end

        try

            tform_cv = fitgeotrans( ...
                input_xy(trainIdx, :), ...
                ref_xy(trainIdx, :), ...
                "polynomial", ...
                degree);

            [pred_x, pred_y] = transformPointsInverse( ...
                tform_cv, ...
                ref_xy(testIdx, 1), ...
                ref_xy(testIdx, 2));

            pred_xy = [pred_x pred_y];

            err = sqrt(sum((pred_xy - input_xy(testIdx, :)).^2, 2));

            allErr = [allErr; err]; %#ok<AGROW>

        catch ME

            validDegree = false;
            failureReason = ME.message;

            break

        end

    end

    cvResults(dd).valid = validDegree;
    cvResults(dd).failure_reason = failureReason;

    if validDegree && ~isempty(allErr)

        cvResults(dd).rms_error_px = sqrt(mean(allErr.^2));
        cvResults(dd).mean_error_px = mean(allErr);
        cvResults(dd).median_error_px = median(allErr);
        cvResults(dd).max_error_px = max(allErr);
        cvResults(dd).p95_error_px = prctile(allErr, 95);

    else

        cvResults(dd).rms_error_px = NaN;
        cvResults(dd).mean_error_px = NaN;
        cvResults(dd).median_error_px = NaN;
        cvResults(dd).max_error_px = NaN;
        cvResults(dd).p95_error_px = NaN;

    end

end

end