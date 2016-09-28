
/**
 * 	Document Class for NFB/Interactive stories
 * 	@version: 1.4
 * 	@date: November 25, 2010
 */

package ca.nfb.interactive.videoplayer {
	import com.gskinner.motion.GTween;
	import com.gskinner.motion.GTweener;
	
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.display.StageQuality;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.MouseEvent;
	import flash.events.NetStatusEvent;
	import flash.events.ProgressEvent;
	import flash.events.TimerEvent;
	import flash.events.TouchEvent;
	import flash.geom.ColorTransform;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.media.Sound;
	import flash.media.SoundChannel;
	import flash.media.SoundTransform;
	import flash.net.URLRequest;
	import flash.system.Capabilities;
	import flash.system.Security;
	import flash.text.TextFormat;
	import flash.ui.Mouse;
	import flash.ui.MouseCursorData;
	import flash.ui.Multitouch;
	import flash.ui.MultitouchInputMode;
	import flash.utils.Timer;
	
	import ca.nfb.interactive.content.AboutScreen;
	import ca.nfb.interactive.content.CreditsScreen;
	import ca.nfb.interactive.content.LoadScreen;
	import ca.nfb.interactive.content.RelatedScreen;
	import ca.nfb.interactive.content.SliderContainer;
	import ca.nfb.interactive.data.MediaData;
	import ca.nfb.interactive.data.MediaSegment;
	import ca.nfb.interactive.data.SectionLink;
	import ca.nfb.interactive.data.Strings;
	import ca.nfb.interactive.display.AbstractVideoPlayer;
	import ca.nfb.interactive.display.VideoPlayerBitmapData;
	import ca.nfb.interactive.display.events.VideoPlayerEvent;
	import ca.nfb.interactive.log.Log;
	import ca.nfb.interactive.performanceprofiling.PerformanceProfiler;
	import ca.nfb.interactive.utils.FileUtil;
	import ca.nfb.interactive.utils.TweenUtil;
	import ca.nfb.interactive.videoplayer.events.MainPlayerEvent;
	
	public class MainPlayer extends Sprite {
		
		// STATES
		public static const STATE_LOAD:uint = 0;
		public static const STATE_LOGO:uint = 1;
		public static const STATE_TITLE:uint = 2;
		public static const STATE_LANG_SELECT:uint = 3;
		public static const STATE_LOAD_SELECT:uint = 4;
		public static const STATE_PREPARE_STREAM:uint = 5;
		public static const STATE_TUTORIAL:uint = 6;
		public static const STATE_EXPERIENCE:uint = 7;
		public static const STATE_DECISION:uint = 8;
		public static const STATE_ABOUT:uint = 9;
		public static const STATE_CREDITS:uint = 10;
		public static const STATE_RELATED:uint = 11;
		public static const STATE_END:uint = 12;
		
		// CURSORS
		private static const CURSOR_OPEN:Number = 2;
		private static const CURSOR_CLOSED:Number = 4;
		private static const CURSOR_POINT:Number = 3;
		private static const CURSOR_FADED:String = "_fade";
		
		// CONSTANTS
		private static const TIMELINE_PADDING:Number = 16;
		private static const TIMELINE_HEIGHT:Number = 22;
		private static const TIMELINE_FADE_TIME:Number = 4000;
		private static const PROGRESS_FADE_OUT_TIME:Number = 5000;
		private static const UI_SCALE:Number = 1;
		private static const PROMPT_WAIT_TIME_MS:Number = 2000;
		
		private static const MENU_OPTION_PADDING:Number = 20;
		private static const MENU_FADE_TIME:Number = 2;
		
		private static const NFB_IN:Number = 1;
		private static const NFB_OUT:Number = 3;
		
		private static const MASK_OPEN_OFFSET:Number = 200;
		private static const MASK_EDGE_PADDING:Number = 150;
		private static const MASK_CLOSE_OFFSET:Number = 12;
		
		private static const GRIP_SPACING:Number = 0; // Distance allowed between grips.
		
		private static var SUPPORTS_VIDEO_TEXTURE:Boolean = false;
		
		// Public variables
		protected var progressBarStartX:Number = 0;
		protected var progressBarStartY:Number = 0;
		
		// Main display container
		protected var mainContainer:Sprite;
		
		// Video dimensions
		public var stageTop:int = 0;
		public var stageW:int = 0;
		public var stageH:int = 0;
		
		// Original container dimensions. Does not change.
		public var mainW:int = 992;
		public var mainH:int = 550;
		
		private var playState:int = -1;
		private var prevState:int = 0;
		
		private var prevTime:Number;
		private var prevStreamPercentile:Number;
		private var promptTime:Number;
		
		// Information about current device.
		private var deviceName:String;
		private var deviceType:String;
		private var deviceVersion:Number;
		
		// Video players
		// Menu loop
		private var introLoopData:MediaData;
		private var menuData:MediaData;
		
		// Main video
		private var mainData:MediaData;
		
		// Video holders
		private var vidHolderLeft:MovieClip;
		private var vidHolderMid:MovieClip;
		private var vidHolderRight:MovieClip;
		
		private var videoPlayer:AbstractVideoPlayer;
		
		private var leftSliderContainer:SliderContainer;
		private var rightSliderContainer:SliderContainer;
		private var leftGripPlaceholder:MovieClip;
		private var rightGripPlaceholder:MovieClip;
		
		private var sliderLeftDragActive:Boolean;
		private var sliderRightDragActive:Boolean;
		private var maskPadding:Number = 0;
		private var maskSpacing:Number = 0;
		private var gripMouseX:Number = 0;
		
		private var progressDragActive:Boolean;
		private var bufferClip:MovieClip;
		private var progressHolder:MovieClip;
		private var progressFadeOutTime:Number = 0;
		private var videoDuration:Number = 0;
		private var pH:Number;
		private var ptH:Number;
		private var sectionLinkContainer:Sprite;
		private var sectionLinks:Vector.<SectionLink>;
		private var prgPixels:Number;
		
		private var pausePlayButton:MovieClip;
		private var scrub:MovieClip;
		private var timelineHeightMax:Number = TIMELINE_HEIGHT;
		private var timelineHeightMin:Number = TIMELINE_HEIGHT / 5.5;
		
		private var videoLoaded:Boolean = false;
		
		private var volumeControl:SoundTransform;
		private var targetFade:Number = 0;
		private var timelineFade:Number = 0;
		private var prevStateTimer:Timer = new Timer(1, 1);
		
		private var firstRun:Boolean = false;
		private var lang:String;
		private var decisionTime:Number;
		private var decisionMade:Boolean = false;
		private var sliderLeftFreezePos:Number;
		private var sliderRightFreezePos:Number;
		private var isFrozen:Boolean;
		private var isMuted:Boolean = false;
		private var isPaused:Boolean = false;
		private var leftDecisionStart:Number;
		private var leftDecisionEnd:Number;
		private var rightDecisionStart:Number;
		private var rightDecisionEnd:Number;
		private var midDecisionStart:Number;
		private var midDecisionEnd:Number;
		private var startVideoAt:Number;
		private var endVideoAt:Number;
		
		private var allowDrag:Point;
		private var endJeff:MovieClip;
		private var endChana:MovieClip;
		private var endVon:MovieClip;
		private var selectionHolder:MovieClip;
		private var selectionStatus:Vector.<Boolean> = new Vector.<Boolean>(3);
		
		private var beginButton:MovieClip;
		private var englishButton:MovieClip;
		private var frenchButton:MovieClip;
		private var khmerButton:MovieClip;
		private var downloadButton:MovieClip;
		private var streamButton:MovieClip;
		private var fastButton:MovieClip;
		private var slowButton:MovieClip;
		private var jeffButton:MovieClip;
		private var chanaButton:MovieClip;
		private var vonButton:MovieClip;
		private var replayButton:MovieClip;
		private var aboutButton:MovieClip;
		private var creditsButton:MovieClip;
		private var closeButton:MovieClip;
		private var navigationButton:MovieClip;
		
		private var menuHolder:MovieClip;
		private var menuTitle:MovieClip;
		private var menuSubTitle:MovieClip;
		private var menuLanguage:MovieClip;
		private var menuOptions:Sprite;
		
		private var aboutScreen:AboutScreen;
		private var creditsScreen:CreditsScreen;
		private var loadScreen:LoadScreen;
		private var relatedScreen:RelatedScreen;
		private var nfblogo:MovieClip;
		private var loadBarWidth:Number;
		private var blackout:MovieClip;
		private var playTimer:Number;
		private var nfbtargetAlpha:Number;
		private var introLoop:Sound;
		private var introChannel:SoundChannel;
		private var introLoopPauseTime:Number = 0;
		private var mouseIsDown:Boolean;
		private var mouseMoved:Boolean;
		private var prevMouse:Point = new Point(0, 0);
		private var prevMouseXVel:Number = 0;
		
		private var secondsElapsedTimer:Timer;
		private var percentLoaded:Number = 0;
		private var loadedCount:int = 0;
		private var loadedTotal:int = 2;
		private var bandwidthArray:Vector.<Number> = new Vector.<Number>();
		private var avgBandwidth:Number = 0; // Average bytes per second.
		
		private var useTouch:Boolean = false;
		private var touchPointCurr:Vector.<Number>;
		private var touchPointPrev:Vector.<Number>;
		private var firstTouchOn:int = 0;
		private var secondTouchOn:int = 0;
		private var prevTouchLeftVel:Number = 0;
		private var prevTouchRightVel:Number = 0;
		private var firstTouchId:int = -1;
		private var secondTouchId:int = -1;
		
		public function MainPlayer() {
			super();
			volumeControl = new SoundTransform(1);
			
			// Get device information.
			var manu:String = Capabilities.manufacturer.toLowerCase();
			var os:String = Capabilities.os.toLowerCase();
			var osVars:Array = os.split(/[^a-z0-9\.]/g);
			
			for (var i:int = 0; i < osVars.length; i++) {
				if (isNaN(deviceVersion) && osVars[i].search(/[^a-z][0-9]+/) >= 0) {
					// Must be a version number.
					deviceVersion = parseFloat(osVars[i]);
					break;
				}
			}
			if (manu.indexOf("ios") >= 0) {
				if (os.indexOf("ipad") >= 0) {
					deviceName = "ipad";
					deviceType = "tablet";
				} else if (os.indexOf("ipod") >= 0) {
					deviceName = "ipod";
					deviceType = "mobile";
				} else if (os.indexOf("iphone") >= 0) {
					deviceName = "iphone";
					deviceType = "mobile";
				}
				for (i = 0; i < osVars.length; i++) {
					if (osVars[i].search(/[a-zA-Z]\d+/) >= 0) {
						// Must be a device version number.
						deviceVersion = osVars[i].split(deviceName)[1];
					}
				}
			} else if (manu.indexOf("android") >= 0) {
				deviceName = "android";
				deviceType = "mobile";
				deviceVersion = os.split("-")[0].split(" ")[1];
			} else if (manu.indexOf("mac") >= 0) {
				deviceName = "mac";
				deviceType = "desktop";
			} else if (manu.indexOf("windows") >= 0) {
				deviceName = "windows";
				deviceType = "desktop";
			}
			
			useTouch = (deviceType == "mobile" || deviceType == "tablet");
			Log.USE_LOG && Log.logmsg("DEVICE: " + deviceName + " - " + deviceVersion + " - " + deviceType + " ----- " + manu + " : " + os);
		}
		
		//---------------------------------------------------------------------------
		//
		//	Getters / setters.
		//
		//---------------------------------------------------------------------------
		
		public function set timelineHeight(value:Number):void {
			timelineHeightMax = value;
			timelineHeightMin = value / 5.5;
			
			if (sectionLinks) {
				for each (var lnk:SectionLink in sectionLinks) {
					lnk.clip.scaleX = lnk.clip.scaleY = timelineHeightMax / TIMELINE_HEIGHT;
				}
			}
		}
		
		public function set menuVideoData(value:MediaData):void {
			menuData = value;
			value.playType = MediaData.TYPE_MASKED_VID;
			value.videoName = Strings.VIDEO_MENU;
			value.onNetStatus = handleMenuStatus;
			
			// Load menu
			if (videoPlayer) {
				videoPlayer.addVideo(value);
			}
		}
		
		public function set mainVideoData(value:MediaData):void {
			mainData = value;
			value.playType = MediaData.TYPE_SEGMENTED_VID;
			value.videoName = Strings.VIDEO_MAIN;
			value.onNetStatus = handleMainStatus;
			
			// Load main
			if (videoPlayer) {
				videoPlayer.addVideo(value);
			}
			
			var extraData:XML = value.extraData;
			
			// Set data regarding decision times.
			if (extraData.decision) {
				decisionTime = extraData.decision.@time;
				sliderLeftFreezePos = extraData.decision.@grip1x;
				sliderRightFreezePos = extraData.decision.@grip2x;
				
				leftDecisionStart = extraData.decision.leftchoice.@start;
				leftDecisionEnd = extraData.decision.leftchoice.@end;
				rightDecisionStart = extraData.decision.rightchoice.@start;
				rightDecisionEnd = extraData.decision.rightchoice.@end;
				midDecisionStart = extraData.decision.midchoice.@start;
				midDecisionEnd = extraData.decision.midchoice.@end;
				
				// Add average playtime of additional segments to decisionTime to get average videoDuration for timeline display.
				videoDuration = decisionTime;
				videoDuration += ((leftDecisionEnd - leftDecisionStart) + (midDecisionEnd - midDecisionStart) + (rightDecisionEnd - rightDecisionStart)) / 3;
			}
			
			// Populate the progress bar's section links.
			if (extraData.sections) {
				Log.USE_LOG && Log.logmsg('XML sections found');
				
				// If sectionLinks already exist, clear the container.
				if (sectionLinks) { sectionLinkContainer.removeChildren(); }
				
				var barWidth:Number = stageW - TIMELINE_PADDING - progressBarStartX;
				sectionLinks = new Vector.<SectionLink>();
				for each (var keyframe:XML in extraData.sections.*) {
					// Create each link in their respective position with text.
					var lnk:SectionLink = new SectionLink();
					//logmsg(keyframe.@name);
					lnk.title = keyframe.@name;
					lnk.time = keyframe.@time;
					lnk.clip.mouseEnabled = true;
					lnk.clip.addEventListener(MouseEvent.CLICK, timelineJump);
					lnk.clip.scaleX = lnk.clip.scaleY = timelineHeightMax / TIMELINE_HEIGHT;
					sectionLinkContainer.addChild(lnk.clip);
					sectionLinks.push(lnk);
					lnk.ttxt.mouseEnabled = false;
					lnk.ttxt.text = lnk.title;
					lnk.gotoAndStop(lang + "-mini");
					if (lang == "kh") { 
						var format:TextFormat = lnk.ttxt.getTextFormat();
						format.font = "Khmer OS";
						lnk.ttxt.defaultTextFormat = format;
						lnk.ttxt.setTextFormat(format);
					}
					lnk.clip.x = barWidth * (lnk.time / videoDuration);
				}
			}
			
		}
		
		public function set introLoopMediaData(value:MediaData):void {
			introLoopData = value;
			
			// Load intro loop.
			var req:URLRequest = new URLRequest(value.url);
			introLoop = new Sound(req);
			introLoop.addEventListener(IOErrorEvent.IO_ERROR, handleMediaLoadError, false, 0, true);
			introLoop.addEventListener(ProgressEvent.PROGRESS, handleSoundLoadProgress, false, 0, true);
			introLoop.addEventListener(Event.COMPLETE, onIntroLoopLoadComplete, false, 0, true);
		}
		
		//---------------------------------------------------------------------------
		//
		//	Public Methods
		//
		//---------------------------------------------------------------------------
		
		/**
		 * 	parseConfig() should be run before start, as it contains initialization
		 *  values such as MediaData, language, about text, etc.
		 */
		public function parseConfig(xml:XML):void {
			if (xml.shareurl) {
				// Base URL.
				Strings.baseUrl = String(xml.shareurl).toLowerCase();
			}
			if (xml.lang) {
				// Setup language data.
				Strings.lang = String(xml.lang).toLowerCase();
			}
			
			if (xml.videos) {
				// Setup video data.
				parseMediaData(xml.videos);
			}
			
			if (xml.about) {
				// Set up about text.
				Strings.aboutTextEn = String(xml.about.@contenten);
				Strings.aboutTextFr = String(xml.about.@contentfr);
				Strings.aboutTextKh = String(xml.about.@contentkh);
			}
			if (xml.aboutImages) {
				// Set up about images.
				Strings.aboutImages = XMLList(xml.aboutImages);
			}
		}
		
		/**
		 * 	The start() method is called by the framework when your main story SWF
		 *	has completed loading.
		 * 	Use this method to begin loading and initializing any story assets
		 * 	that need to be available at the start of your story.
		 * 	The baseURL property is now available and should be prepended to your
		 *	asset file paths. e.g. imagePath = baseURL + "images/photo01.jpg".
		 * 	After your assets are loaded, call readyToAnimate().
		 */
		public function start(player:AbstractVideoPlayer, playerWidth:Number, playerHeight:Number):void {
			// Start framerate profiler
			PerformanceProfiler.fpsStart();
			
			mainW = playerWidth;
			mainH = playerHeight;
			
			// Start off with the main container.
			mainContainer = new Sprite();
			
			// Start internal preloader and start loading assets. Remember to prepend
			// baseURL to your asset file paths.
			stage.quality = StageQuality.HIGH;
			stageW = stage.stageWidth;
			stageH = stage.stageHeight;
			
			mouseIsDown = false;
			isFrozen = false;
			
			// Timer to switch to previous state.
			prevStateTimer = new Timer(20, 1);
			prevStateTimer.addEventListener(TimerEvent.TIMER_COMPLETE, returnToPrevState, false, 0, true);
			
			pH = timelineHeightMin;
			ptH = timelineHeightMin;
			
			buildSelectionHolder();
			
			/* ======================================== */
			// Create video holder segments. These display the video.
			
			vidHolderLeft = new MovieClip();
			vidHolderMid = new MovieClip();
			vidHolderRight = new MovieClip();
			
			vidHolderLeft.visible = false;
			vidHolderRight.visible = false;
			
			// Create the slider container.
			leftSliderContainer = new SliderContainer(/* right side */ false, mainW, mainH, MASK_OPEN_OFFSET, useTouch);
			rightSliderContainer = new SliderContainer(/* right side */ true, mainW, mainH, MASK_OPEN_OFFSET, useTouch);
			
			// Create the video player. This depends on if VideoTexture is available or not.
			videoPlayer = player;
			if (videoPlayer is VideoPlayerBitmapData) {
				// Use BitmapData to render videos.
				Log.USE_LOG && Log.logmsg("Use BitmapData to render video.");
				SUPPORTS_VIDEO_TEXTURE = false;
				var bitmaps:Vector.<Bitmap> = (videoPlayer as VideoPlayerBitmapData).bitmaps;
				
				vidHolderLeft.addChild(bitmaps[0]);
				vidHolderMid.addChild(bitmaps[1]);
				vidHolderRight.addChild(bitmaps[2]);
				
				videoPlayer.addEventListener(VideoPlayerEvent.MEDIA_PROGRESS, handleMediaLoadProgress, false, 0, true);
				videoPlayer.addEventListener(VideoPlayerEvent.MEDIA_FAILED, handleMediaLoadFailed, false, 0, true);
				videoPlayer.addEventListener(VideoPlayerEvent.MEDIA_LOADED, handleMediaLoadSuccess, false, 0, true);
				videoPlayer.addEventListener(VideoPlayerEvent.RESIZED, handleMediaResized, false, 0, true);
				
				// Add the masks. Only bitmapData player uses them.
				vidHolderLeft.mask = leftSliderContainer.vidMask;
				vidHolderRight.mask = rightSliderContainer.vidMask;
				
				dispatchEvent(new MainPlayerEvent(MainPlayerEvent.READY_TO_RECEIVE_MEDIA));
			} else {
				// Use VideoTexture to render videos.
				Log.USE_LOG && Log.logmsg("Use VideoTexture to render video.");
				SUPPORTS_VIDEO_TEXTURE = true;
				videoPlayer.addEventListener(Event.CONTEXT3D_CREATE, onContext3DReady, false, 0, true);
				videoPlayer.addEventListener(VideoPlayerEvent.MEDIA_PROGRESS, handleMediaLoadProgress, false, 0, true);
				videoPlayer.addEventListener(VideoPlayerEvent.MEDIA_FAILED, handleMediaLoadFailed, false, 0, true);
				videoPlayer.addEventListener(VideoPlayerEvent.MEDIA_LOADED, handleMediaLoadSuccess, false, 0, true);
				videoPlayer.addEventListener(VideoPlayerEvent.RESIZED, handleMediaResized, false, 0, true);
				
				// Don't use masking here.
				leftSliderContainer.vidMask.visible = false;
				rightSliderContainer.vidMask.visible = false;
			}
			
			if (menuData) { videoPlayer.addVideo(menuData); }
			if (mainData) { videoPlayer.addVideo(mainData); }
			
			startVideoAt = 0;
			endVideoAt = Number.MAX_VALUE;
			
			// Create grip buttons. These are invisible.
			leftGripPlaceholder = new vidMaskLeft();
			rightGripPlaceholder = new vidMaskRight();
			leftGripPlaceholder.visible = rightGripPlaceholder.visible = false;
			leftGripPlaceholder.mouseEnabled = true;
			rightGripPlaceholder.mouseEnabled = true;
			leftGripPlaceholder.x = 0 - MASK_OPEN_OFFSET;
			rightGripPlaceholder.x = mainW + MASK_OPEN_OFFSET;
			leftGripPlaceholder.cacheAsBitmap = true;
			rightGripPlaceholder.cacheAsBitmap = true;
			
			sliderLeftDragActive = false;
			sliderRightDragActive = false;
			maskPadding = MASK_EDGE_PADDING;
			maskSpacing = GRIP_SPACING;
			
			/* Tutorial */
			allowDrag = new Point();
			
			// This is the buffer clip that appears when something is preloading.
			bufferClip = new buffering();
			bufferClip.x = 200;
			bufferClip.y = 200;
			bufferClip.visible = false;
			
			// This is the timeline the user can use to navigate the video.
			progressHolder = new MovieClip();
			
			scrub = new ScrubMarker();
			scrub.gotoAndStop(1);
			scrub.visible = false;
			
			pausePlayButton = new PausePlayButton();
			pausePlayButton.gotoAndStop(1);
			pausePlayButton.scaleX = pausePlayButton.scaleY = (timelineHeightMax / pausePlayButton.height);
			
			navigationButton = new ButtonNavigation();
			navigationButton.scaleX = navigationButton.scaleY = (timelineHeightMax * .6 / navigationButton.height);
			navigationButton.visible = false;
			navigationButton.alpha = 0;
			navigationButton.addEventListener(MouseEvent.CLICK, onClickNavigation, false, 0, true);
			
			// Populate progress holder with links.
			sectionLinkContainer = new Sprite();
			toggleUI(false);
			
			// Timer that ticks every second.
			secondsElapsedTimer = new Timer(1000);
			secondsElapsedTimer.addEventListener(TimerEvent.TIMER, onSecond);
			secondsElapsedTimer.start();
			
			// Update method.
			addEventListener(Event.ENTER_FRAME, update, false, 0, true);
			
			// Create main menu.
			addMainMenuItems();
			
			// Register cursor clips. This overrides the mouse cursor.
			var cursor:CursorClip = new CursorClip();
			
			registerCursorClip(CURSOR_OPEN, cursor);
			registerCursorClip(CURSOR_POINT, cursor);
			registerCursorClip(CURSOR_CLOSED, cursor);
			setCursorPointer(null);
			
			// Add mouse or touch events.
			if (useTouch) {
				// Get touch events.
				Multitouch.inputMode = MultitouchInputMode.TOUCH_POINT;
				if (Multitouch.maxTouchPoints >= 2) {
					// Use multiple touch points.
					touchPointCurr = new Vector.<Number>();
					touchPointCurr[0] = 0;
					touchPointCurr[1] = 0;
					touchPointPrev = new Vector.<Number>();
					touchPointPrev[0] = 0;
					touchPointPrev[1] = 0;
					stage.addEventListener(TouchEvent.TOUCH_MOVE, handleTouchMove);
				}
				stage.addEventListener(TouchEvent.TOUCH_BEGIN, handleTouchDown);
				stage.addEventListener(TouchEvent.TOUCH_END, handleTouchUp);
			} else {
				stage.addEventListener(MouseEvent.MOUSE_DOWN, handleMouseDown);
				stage.addEventListener(MouseEvent.MOUSE_UP, handleMouseUp);
			}
			
			aboutScreen = new AboutScreen();
			aboutScreen.setSize(mainW, mainH);
			aboutScreen.visible = false;
			aboutScreen.addEventListener(Event.CLOSE, closeAbout, false, 0, true);
			
			creditsScreen = new CreditsScreen();
			creditsScreen.setSize(mainW, mainH);
			creditsScreen.visible = false;
			creditsScreen.addEventListener(Event.CLOSE, closeCredits, false, 0, true);
			
			relatedScreen = new RelatedScreen();
			relatedScreen.setSize(mainW, mainH);
			relatedScreen.visible = false;
			relatedScreen.addEventListener(Event.CLOSE, closeRelated, false, 0, true);
			
			loadScreen = new LoadScreen(mainW, mainH);
			loadScreen.x = mainW * .5;
			loadScreen.y = mainH * .5;
			loadScreen.addEventListener(Event.COMPLETE, handleFullyLoaded, false, 0, true);
			
			nfblogo = new NFB_Logo();
			nfblogo.x = mainW * .5;
			nfblogo.y = mainH * .5;
			nfblogo.alpha = 0;
			nfbtargetAlpha = 0;
			nfblogo.mouseChildren = nfblogo.mouseEnabled = false;
			
			blackout = new Blackout();
			blackout.x = 0;
			blackout.y = 0;
			blackout.mouseChildren = blackout.mouseEnabled = false;
			
			// Add everything to the main container, in order.
			addChild(mainContainer);
			setChildIndex(mainContainer, 0);
			
			// Add user progress control.
			addChild(progressHolder);
			addChild(scrub);
			addChild(sectionLinkContainer);
			addChild(pausePlayButton);
			if (useTouch) {
				//addChild(navigationButton); // DEBUG - USE NAVIGATION BUTTON
			}
			
			// Add selection holder.
			addChild(selectionHolder);
			
			// Use pausePlayButton to get start x-position for progress bar.
			var bounds:Rectangle = pausePlayButton.getBounds(this);
			pausePlayButton.x = TIMELINE_PADDING - bounds.left;
			pausePlayButton.y = stageTop + stageH - TIMELINE_PADDING - (pausePlayButton.height * .5);
			navigationButton.x = TIMELINE_PADDING + navigationButton.width * .5;
			navigationButton.y = stageTop + stageH - navigationButton.height; // On the BotNav bar.
			progressBarStartX = pausePlayButton.x;
			progressBarStartY = pausePlayButton.y;
			
			// Base video holder right in the back.
			mainContainer.addChild(vidHolderMid);
			mainContainer.addChild(blackout);
			
			// Add menu holder.
			mainContainer.addChild(menuHolder);
			
			// Add the "wings".
			mainContainer.addChild(vidHolderLeft);
			mainContainer.addChild(vidHolderRight);
			mainContainer.addChild(leftSliderContainer);
			mainContainer.addChild(rightSliderContainer);
			mainContainer.addChild(leftGripPlaceholder);
			mainContainer.addChild(rightGripPlaceholder);
			
			// Add overlay screens and logo.
			mainContainer.addChild(aboutScreen);
			mainContainer.addChild(creditsScreen);
			mainContainer.addChild(relatedScreen);
			mainContainer.addChild(loadScreen);
			mainContainer.addChild(nfblogo);
			
			// Add buffering clip.
			mainContainer.addChild(bufferClip);
			
			playTimer = 0;
			
			if (Strings.lang) {
				langSelected(Strings.lang);
			}
			
			setState(STATE_LOAD);
			// Lower the quality now that everything's rendered.
			//stage.quality = StageQuality.LOW;
			
			// Autosize the main container.
			handleMediaResized(null);
			
			// Setup the media data. Strings should have the values in by now.
			setupInitialLoadData();
			
			track("Start");
		}
		
		/**
		 * 	The pause() method is called by the framework when displaying framework
		 * 	link content. e.g. ABOUT THE FILM, RELATED FILMS 
		 * 	Use this method to pause any animation, video, or anything that takes CPU
		 *	cycles. Your story should be able to indicate whether or not it is paused
		 * 	by using BaseNFB.isPaused.
		 * 	Background audio is an exception and should not pause, so that the user
		 *	doesn't feel like they completely left the story.
		 */
		public function pause():void {
			isPaused = true;
			
			// Pause any audio, animations or video or anything that takes cpu cycles
			videoPlayer.pause();
			introChannel.stop();
			introLoopPauseTime = introChannel.position;
			
			// pause() can be called at any time so it is important to use exception
			// handling for any references to display objects which may or may not 
			// exist to prevent the script from terminating due to an error.
			removeEventListener(Event.ENTER_FRAME, update, false);
			
			// Stop framerate profiler
			PerformanceProfiler.fpsStop();
			
			track("Pause");
		}
		
		/**
		 * 	The resume() method is called by the framework when the framework
		 * 	menu is closed. 
		 * 	Use this method to resume playing all files that were paused.
		 *	Your story should be able to indicate whether or not it is paused
		 * 	by using BaseNFB.isPaused.
		 */
		public function resume():void {
			isPaused = false;
			
			// Resume playing audio, animations and video
			videoPlayer.resume();
			if (!introChannel && introLoop && playState != STATE_EXPERIENCE && playState != STATE_DECISION && playState != STATE_LOGO && playState != STATE_CREDITS) {
				introChannel = introLoop.play(introLoopPauseTime, 9999, volumeControl);
			}
			
			// resume() can be called at any time so it is important to use exception
			// handling for any references to display objects which may or may not 
			// exist to prevent the script from terminating due to an error.
			addEventListener(Event.ENTER_FRAME, update, false, 0, true);
			
			// Start framerate profiler
			PerformanceProfiler.fpsStart();
			
			track("Resume");
		}
		
		public function mute():void {
			Log.USE_LOG && Log.logmsg("Mute Video");
			
			isMuted = true;
			videoPlayer.volume = 0;
			volumeControl.volume = 0;
			if (introChannel) { introChannel.soundTransform = volumeControl; }
		}
		
		public function unmute():void {
			Log.USE_LOG && Log.logmsg("Unmute Video");
			isMuted = false;
			videoPlayer.volume = 1;
			volumeControl.volume = 1;
			if (introChannel) { introChannel.soundTransform = volumeControl; }
		}
		
		/**
		 * 	The resize() method is called by the framework when the browser window
		 * 	dimensions change.
		 * 	Stories should not be coded to use stage.stageWidth and stage.stageHeight,
		 * 	except for out-of-framework testing. Instead, all assets should use the 
		 * 	containerWidth and containerHeight properties provided by the framework.
		 * 	The minimum size of the content area is 992x550, dictated by the framework.
		 *
		 * 	@param containerWidth 	Pixels between the right and left sides of browser
		 * 	@param containerHeight	Pixels between the bottom of the framework header
		 *							and the top of the framework footer.
		 */
		public function resize(containerWidth:Number, containerHeight:Number):void {
			Log.USE_LOG && Log.logmsg("SCALE TO: " + containerWidth + " / " + containerHeight);
			stageW = containerWidth;
			stageH = containerHeight;
			
			if (videoPlayer) {
				// Scale the stage dimensions. Also pass in the real stage dimensions for VideoTexture and StageVideo displays.
				videoPlayer.resize(
					containerWidth,
					containerHeight
				);
			}
			
			// Reposition the progress bar.
			if (pausePlayButton) {
				progressBarStartY = containerHeight + stageTop - TIMELINE_PADDING - (pausePlayButton.height * .5);
				pausePlayButton.y = progressBarStartY;
				navigationButton.y = progressBarStartY;
			}
			
			if (sectionLinkContainer) {
				// Move progress bar elements.
				sectionLinkContainer.x = progressBarStartX;
				sectionLinkContainer.y = progressBarStartY;
				
				var barWidth:Number = containerWidth - TIMELINE_PADDING - progressBarStartX;
				for each (var link:SectionLink in sectionLinks) {
					link.clip.x = barWidth * (link.time / videoDuration);
				}
			}
			
			if (playState == STATE_EXPERIENCE) {
				// Update the progress bar here so there's no jump-frames.
				updateProgressBar(0);
			}
		}
		
		/**********************************************************
		 * CHANGE STATE
		 **********************************************************/
		
		public function setState(state:int):void {
			if (state == playState || state < 0) { return; }
			
			Log.USE_LOG && Log.logmsg("New State: " + state);
			
			// Pause everything. Whatever's supposed to play will be resumed immediately.
			videoPlayer.pause();
			
			// Make sure we have intro playing unless told otherwise.
			if (!introChannel && introLoop && introLoop.bytesTotal > 0) {
				introChannel = introLoop.play(0, 9999, volumeControl);
			}
			
			// Start opened.
			leftGripPlaceholder.x = 0 - MASK_OPEN_OFFSET;
			rightGripPlaceholder.x = mainW + MASK_OPEN_OFFSET;
			
			// Remove everything. If something is needed, it will be made visible again.
			vidHolderLeft.visible = vidHolderRight.visible = false;
			leftSliderContainer.vidFade.visible = rightSliderContainer.vidFade.visible = false;
			aboutScreen.visible = false;
			creditsScreen.visible = false;
			relatedScreen.visible = false;
			loadScreen.visible = false;
			allowDrag.x = allowDrag.y = 0;
			toggleUI(false);
			
			setupMenuTitle();
			videoPlayer.cancelFading();
			
			if (playState == STATE_CREDITS) {
				creditsScreen.reset();
			}
			
			switch (state) {
				case STATE_LOAD:
					blackout.visible = false;
					menuTitle.visible = false;
					menuSubTitle.visible = false;
					loadScreen.visible = true;
					break;
				case STATE_LOGO:
					// Fade in the NFB logo for a moment, then fade out again.
					menuHolder.visible = false;
					blackout.visible = false;
					blackout.alpha = 1;
					playTimer = 0;
					track("Logo");
					break;
				case STATE_TITLE:
					videoPlayer.showVideo(Strings.VIDEO_MENU);
					videoPlayer.seek(0);
					videoPlayer.resume();
					
					menuTitle.alpha = 0;
					menuSubTitle.alpha = 0;
					
					// Quick cinematic tween. Fade blackout a bit, fade in title, fade in subtitle.
					TweenUtil.fadeIn(blackout, 2, 0.7).onComplete = function (t:GTween):void {
						TweenUtil.handleTweenComplete(t);
						
						TweenUtil.fadeIn(menuTitle, 2).onComplete = function (t:GTween):void {
							TweenUtil.handleTweenComplete(t);
							TweenUtil.fadeIn(menuSubTitle, 2).onComplete = function (t:GTween):void {
								TweenUtil.handleTweenComplete(t);
								onTitleFinished();
							};
						};
					};
					track("Title");
					break;
				case STATE_LANG_SELECT:
					// Display the menu and language buttons.
					videoPlayer.showVideo(Strings.VIDEO_MENU);
					videoPlayer.resume();
					
					TweenUtil.fadeIn(blackout, 1, 0.8);
					TweenUtil.fadeIn(menuLanguage, 1);
					
					displayMenuButton(englishButton);
					displayMenuButton(frenchButton);
					displayMenuButton(khmerButton);
					track("Language Selection");
					break;
				case STATE_LOAD_SELECT:
					// Display the menu and load type buttons.
					videoPlayer.showVideo(Strings.VIDEO_MENU);
					videoPlayer.resume();
					
					TweenUtil.fadeIn(blackout, 1, 0.6);
					
					displayMenuButton(downloadButton); // A43 - Remove Download button until downloads are available.
					displayMenuButton(streamButton);
					
					track("Load Type Selection");
					break;
				case STATE_PREPARE_STREAM:
					// Display load screen again, this time showing progress in loading the stream up to an ideal point.
					videoPlayer.showVideo(Strings.VIDEO_MENU);
					videoPlayer.resume();
					
					menuTitle.visible = false;
					menuSubTitle.visible = false;
					loadScreen.visible = true;
					break;
				case STATE_TUTORIAL:
					// Fade out menu holder and allow user to interact with grips.
					videoPlayer.showVideo(Strings.VIDEO_MENU);
					videoPlayer.resume();
					
					// Allow dragging to happen.
					allowDrag.x = allowDrag.y = 1;
					
					// Show vidholders.
					vidHolderLeft.visible = vidHolderRight.visible = true;
					
					GTweener.removeTweens(leftGripPlaceholder);
					GTweener.removeTweens(rightGripPlaceholder);
					
					// Don't show the prompts just yet.
					promptTime = PROMPT_WAIT_TIME_MS;
					leftSliderContainer.instruction.alpha = 0;
					rightSliderContainer.instruction.alpha = 0;
					
					// Fade out the blackout. This, coupled with the grip, will cause a slight ease effect.
					var tutTween:GTween = SUPPORTS_VIDEO_TEXTURE ? TweenUtil.fadeIn(blackout, 2, 0.4) : TweenUtil.fadeIn(blackout, 2, 0.2);
					tutTween.onComplete = function (t:GTween):void {
						// Menu faded out. Clear to begin tutorial.
						TweenUtil.handleTweenComplete(t);
						//blackout.visible = false;
						
						// Show the vidHolders and grips now. They'll be playing with vidHolder2, so you won't see any difference.
						leftSliderContainer.showGrip();
						rightSliderContainer.showGrip();
						
						// Close the sliders a bit to show there's something underneath.
						TweenUtil.moveEase(leftGripPlaceholder, (mainW * .5) - MASK_CLOSE_OFFSET, 2);
						TweenUtil.moveEase(rightGripPlaceholder, (mainW * .5) + MASK_CLOSE_OFFSET, 2);
						
						// Display the begin button.
						TweenUtil.fadeOut(beginButton, 2).onComplete = function (t:GTween):void {
							displayMenuButton(beginButton);
						}
						
						// Hide instructions until prompt time is up.
						leftSliderContainer.instruction.alpha = 0;
						rightSliderContainer.instruction.alpha = 0;
						promptTime = PROMPT_WAIT_TIME_MS;
					};
					track("Tutorial");
					break;
				case STATE_EXPERIENCE:
					// Play the main video.
					videoPlayer.showVideo(Strings.VIDEO_MAIN);
					videoPlayer.seek(startVideoAt);
					videoPlayer.resume();
					
					introChannel.stop();
					introChannel = null;
					
					// Always start the experience playing.
					pausePlayButton.gotoAndStop(2);
					
					// Display the progress holder at the start, so the user knows it exists.
					progressFadeOutTime = PROGRESS_FADE_OUT_TIME;
					toggleUI(true);
					progressHolder.alpha = pausePlayButton.alpha = scrub.alpha = sectionLinkContainer.alpha = 1;
					
					// No easing here. Make everything visible / invisible immediately.
					blackout.visible = false;
					menuHolder.visible = false;
					vidHolderLeft.visible = vidHolderRight.visible = true;
					allowDrag.x = allowDrag.y = 1;
					leftSliderContainer.vidFade.visible = rightSliderContainer.vidFade.visible = true;
					leftSliderContainer.vidFade.alpha = rightSliderContainer.vidFade.alpha = 0;
					
					// Unfreeze and restore video.
					isFrozen = false;
					selectionHolder.visible = false;
					
					// Move the grips to the preset position. Determined by config.xml.
					leftGripPlaceholder.x = sliderLeftFreezePos;
					rightGripPlaceholder.x = sliderRightFreezePos;
					
					// Reveal the progress bar again.
					toggleUI(true);
					
					track("Experience");
					break;
				case STATE_DECISION:
					// Jump to decision time to mesh with buttons.
					videoPlayer.showVideo(Strings.VIDEO_MENU);
					videoPlayer.resume();
					
					// Hit the end of the decision clip. Return to decision screen.
					menuHolder.visible = false;
					selectionHolder.visible = true;
					selectionHolder.alpha = 1;
					
					setEndFrames();
					
					toggleUI(false);
					isFrozen = true;
					decisionMade = false;
					endVideoAt = Number.MAX_VALUE;
					setEndFrames();
					leftGripPlaceholder.x = sliderLeftFreezePos;
					rightGripPlaceholder.x = sliderRightFreezePos;
					
					track("Decision");
					break;
				case STATE_ABOUT:
					// Play menu BG.
					videoPlayer.showVideo(Strings.VIDEO_MENU);
					videoPlayer.resume();
					
					// Hide the menu if it's visible.
					if (menuHolder.visible) {
						TweenUtil.fadeOut(menuHolder, 1).onComplete = function (t:GTween):void {
							TweenUtil.handleTweenComplete(t);
							menuHolder.visible = false;
						};
					}
					
					// Hide the grips to smooth out the BG.
					if (leftSliderContainer.vidFade.visible) {
						TweenUtil.fadeOut(leftSliderContainer.vidFade, 1);
						TweenUtil.fadeOut(rightSliderContainer.vidFade, 1);
					}
					
					// Fade the blackout and all, then fade in about screen.
					TweenUtil.fadeIn(blackout, 1, .7).onComplete = function (t:GTween):void {
						TweenUtil.handleTweenComplete(t);
						aboutScreen.alpha = 0;
						TweenUtil.fadeIn(aboutScreen, 1);
					};
					
					track("About");
					break;
				case STATE_CREDITS:
					// Play menu BG.
					videoPlayer.showVideo(Strings.VIDEO_MENU);
					videoPlayer.resume();
					
					// Hide the menu if it's visible.
					if (menuHolder.visible) {
						TweenUtil.fadeOut(menuHolder, 1).onComplete = function (t:GTween):void {
							TweenUtil.handleTweenComplete(t);
							menuHolder.visible = false;
						};
					}
					
					// Hide the grips to smooth out the BG.
					if (leftSliderContainer.vidFade.visible) {
						TweenUtil.fadeOut(leftSliderContainer.vidFade, 1);
						TweenUtil.fadeOut(rightSliderContainer.vidFade, 1);
					}
					
					// Fade the blackout and all, then fade in about screen.
					TweenUtil.fadeIn(blackout, 1, .7).onComplete = function (t:GTween):void {
						TweenUtil.handleTweenComplete(t);
						creditsScreen.alpha = 0;
						TweenUtil.fadeIn(creditsScreen, 1);
					};
					
					/*
					// Play credits video.
					videoPlayer.showVideo(Strings.VIDEO_CREDITS);
					videoPlayer.seek(0);
					videoPlayer.resume();
					
					introChannel.stop();
					introChannel = null;
					displayMenuButton(closeButton);
					
					// Credits is a non-interactive experience. Simply play.
					blackout.visible = false;
					menuTitle.visible = false;
					menuSubTitle.visible = false;
					*/
					
					track("Credits");
					break;
				case STATE_RELATED:
					// Play menu BG.
					videoPlayer.showVideo(Strings.VIDEO_MENU);
					videoPlayer.resume();
					
					// Hide the menu if it's visible.
					if (menuHolder.visible) {
						TweenUtil.fadeOut(menuHolder, 1).onComplete = function (t:GTween):void {
							TweenUtil.handleTweenComplete(t);
							menuHolder.visible = false;
						};
					}
					
					// Hide the grips to smooth out the BG.
					if (leftSliderContainer.vidFade.visible) {
						TweenUtil.fadeOut(leftSliderContainer.vidFade, 1);
						TweenUtil.fadeOut(rightSliderContainer.vidFade, 1);
					}
					
					// Fade the blackout and all, then fade in about screen.
					TweenUtil.fadeIn(blackout, 1, .7).onComplete = function (t:GTween):void {
						TweenUtil.handleTweenComplete(t);
						relatedScreen.alpha = 0;
						TweenUtil.fadeIn(relatedScreen, 1);
					};
					track("Related");
					break;
				case STATE_END:
					// Loop the menu.
					videoPlayer.showVideo(Strings.VIDEO_MENU);
					videoPlayer.resume();
					
					// No blackout or titles.
					blackout.alpha = 0;
					TweenUtil.fadeIn(blackout, 2, 0.6);
					menuTitle.visible = menuSubTitle.visible = false;
					
					// Display the options again.
					menuOptions.visible = false;
					menuOptions.alpha = 0;
					
					// Fade in the end options.
					displayMenuButton(jeffButton);
					displayMenuButton(chanaButton);
					displayMenuButton(vonButton);
					displayMenuButton(replayButton);
					displayMenuButton(aboutButton);
					displayMenuButton(creditsButton);
					
					TweenUtil.fadeIn(menuOptions, 2);
					track("End");
					break;
				default:
					break;
			}
			
			// Omit invalid prevStates.
			if (
				playState != -1 && 
				playState != STATE_ABOUT && 
				playState != STATE_RELATED && 
				playState != STATE_CREDITS && 
				playState != STATE_LOGO
			) {
				prevState = playState;
			}
			playState = state;
			
			update();
		}
		
		private function returnToPrevState (t:TimerEvent):void {
			prevStateTimer.stop();
			setState(prevState);
		}
		
		//---------------------------------------------------------------------------
		//
		//	Private Methods
		//
		//---------------------------------------------------------------------------
		
		private function registerCursorClip(id:Number, cursor:CursorClip):void {
			var bd:BitmapData = new BitmapData(32, 32);
			var cd:MouseCursorData;
			
			cursor.gotoAndStop(id);
			var hotSpotSprite:Sprite = cursor.getChildByName("hotspot") as Sprite;
			
			var mc:MovieClip = new MovieClip();
			var bb:Rectangle = cursor.getBounds(cursor);
			var hotSpot:Point = new Point(hotSpotSprite.x, hotSpotSprite.y);
			var matrix:Matrix = new Matrix();
			var clipRect:Rectangle = new Rectangle(0, 0, 32, 32);
			
			// Create regular version
			bd.fillRect(clipRect, 0);
			bd.draw(cursor, matrix, new ColorTransform(1, 1, 1, 1));
			
			cd = new MouseCursorData();
			cd.data = new <BitmapData>[bd];
			cd.hotSpot = new Point(hotSpot.x, hotSpot.y);
			Mouse.registerCursor(id.toString(), cd);
			
			// Create faded version
			bd.fillRect(clipRect, 0);
			bd.draw(cursor, matrix, new ColorTransform(1, 1, 1, 0.5));
			
			cd = new MouseCursorData();
			cd.data = new <BitmapData>[bd];
			cd.hotSpot = new Point(hotSpot.x, hotSpot.y);
			Mouse.registerCursor(id.toString() + CURSOR_FADED, cd);
		}
		
		private function toggleUI(active:Boolean):void {
			Log.USE_LOG && Log.logmsg("Toggle UI: " + active);
			if (active) {
				if (useTouch) {
					// navigationButton.visible = true; // DEBUG - USE NAVIGATION BUTTON
				}
				progressHolder.visible = true;
				sectionLinkContainer.visible = true;
				pausePlayButton.visible = true;
				scrub.visible = true;
			} else {
				navigationButton.visible = false;
				progressHolder.visible = false;
				sectionLinkContainer.visible = false;
				pausePlayButton.visible = false;
				scrub.visible = false;
			}
		}
		
		private function onSecond(e:TimerEvent):void {
			playTimer++;
			if (playTimer > NFB_IN) { nfbtargetAlpha = 100; }
			if (playTimer > NFB_OUT) { nfbtargetAlpha = 0; }
		}
		
		private function closeAbout(e:Event):void {
			setState(prevState);
		}
		
		private function closeCredits(e:Event):void {
			setState(prevState);
		}
		
		private function closeRelated(e:Event):void {
			setState(prevState);
		}
		
		private function addMainMenuItems():void {
			menuHolder = new MovieClip();
			menuHolder.visible = false;
			menuHolder.alpha = 0;
			
			// Main title (says Invisible World)
			menuTitle = new MenuTitle();
			menuTitle.gotoAndStop(0);
			menuTitle.x = mainW / 2;
			menuTitle.y = mainH / 4;
			
			// Main subtitle.
			menuSubTitle = new MenuSubTitle();
			menuSubTitle.gotoAndStop(0);
			menuSubTitle.x = mainW / 2;
			menuSubTitle.y = menuTitle.y + menuTitle.height + 50;
			
			// Main language selection instruction.
			menuLanguage = new MenuLanguage();
			menuLanguage.gotoAndStop(0);
			
			// Options sprite. Contains buttons.
			menuOptions = new Sprite();
			
			beginButton = new ButtonBegin();
			beginButton.scaleX = UI_SCALE;
			beginButton.scaleY = UI_SCALE;
			
			englishButton = new ButtonEnglish();
			frenchButton = new ButtonFrench();
			khmerButton = new ButtonKhmer();
			
			downloadButton = new ButtonDownload();
			streamButton = new ButtonStream();
			
			slowButton = new ButtonSlow();
			fastButton = new ButtonFast();
			
			chanaButton = new ButtonChana();
			jeffButton = new ButtonJeff();
			vonButton = new ButtonVon();
			
			// The replay buttons go above the menuOptions y pos, which is quite low already.
			replayButton = new ButtonReplay();
			aboutButton = new ButtonAbout();
			creditsButton = new ButtonCredits();
			
			closeButton = new ButtonClose();
			closeButton.width = MENU_OPTION_PADDING;
			closeButton.height = MENU_OPTION_PADDING;
			
			// Add all the controls and stuff.
			menuHolder.addChild(menuTitle);
			menuHolder.addChild(menuSubTitle);
			menuHolder.addChild(menuLanguage);
			menuHolder.addChild(menuOptions);
			menuHolder.addChild(closeButton);
			
			// Set everything up.
			setupMenuTitle();
			
			setupButton(beginButton, mainW / 2, mainH * 3 / 4, startExperience);
			
			setupButton(englishButton, (mainW / 2) - englishButton.width - MENU_OPTION_PADDING, mainH * 3 / 4, selectLanguage);
			setupButton(frenchButton, mainW / 2, englishButton.y, selectLanguage);
			setupButton(khmerButton, (mainW / 2) + khmerButton.width + MENU_OPTION_PADDING, englishButton.y, selectLanguage);
			
			menuLanguage.x = mainW / 2;
			menuLanguage.y = englishButton.y - (englishButton.height / 2) - menuLanguage.height - MENU_OPTION_PADDING;
			
			// A43 - Removed Download Button until downloads are actually available.
			setupButton(downloadButton, ((mainW - downloadButton.width) / 2) - MENU_OPTION_PADDING, mainH * 3 / 4, selectLoadType);
			setupButton(streamButton, ((mainW + streamButton.width) / 2) + MENU_OPTION_PADDING, downloadButton.y, selectLoadType);
			//setupButton(streamButton, mainW / 2, mainH * 3 / 4, selectLoadType);
			
			setupButton(slowButton, streamButton.x + MENU_OPTION_PADDING, streamButton.y + ((streamButton.height + slowButton.height) * .5) + MENU_OPTION_PADDING, selectStreamLoad);
			setupButton(fastButton, streamButton.x + MENU_OPTION_PADDING, slowButton.y + ((fastButton.height + slowButton.height) * .5) + MENU_OPTION_PADDING, selectStreamLoad);
			
			setupButton(chanaButton, mainW / 2, mainH / 2, jumpToChana);
			setupButton(jeffButton, (mainW / 2) - chanaButton.width - MENU_OPTION_PADDING, chanaButton.y, jumpToJeff);
			setupButton(vonButton, (mainW / 2) + chanaButton.width + MENU_OPTION_PADDING, chanaButton.y, jumpToVon);
			
			setupButton(replayButton, mainW / 2, mainH * 4 / 5, replayExperience);
			setupButton(aboutButton, (mainW / 2) - replayButton.width * 2, replayButton.y, onClickAbout);
			setupButton(creditsButton, (mainW / 2) + replayButton.width * 2, replayButton.y, onClickCredits);
			
			setupButton(closeButton, mainW - MENU_OPTION_PADDING, MENU_OPTION_PADDING, onClickCloseCredits);
		}
		
		private function setupButton(button:MovieClip, x:int, y:int, clickFunc:Function):void {
			button.visible = false;
			if (x != -1) { button.x = x; }
			if (y != -1) { button.y = y; }
			
			try {
				button.gotoAndStop((Strings.lang && Strings.lang != "") ? Strings.lang : 0);
			} catch (e:Error) { }
			
			button.addEventListener(MouseEvent.MOUSE_OVER, setCursorPointer, false, 0, true);
			button.addEventListener(MouseEvent.MOUSE_OUT, setCursorPointerFaded, false, 0, true);
			button.addEventListener(MouseEvent.CLICK, clickFunc, false, 0, true);
			
			menuOptions.addChild(button);
		}
		
		private function buildSelectionHolder():void {
			selectionHolder = new MovieClip();
			selectionHolder.visible = false;
			
			endJeff = new EndClip_Jeff();
			endJeff.gotoAndStop(0);
			selectionHolder.addChild(endJeff);
			
			endChana = new EndClip_Chana();
			endChana.gotoAndStop(0);
			selectionHolder.addChild(endChana);
			
			endVon = new EndClip_Von();
			endVon.gotoAndStop(0);
			selectionHolder.addChild(endVon);
			
			if (useTouch) {
				endJeff.addEventListener(TouchEvent.TOUCH_BEGIN, decisionRollOver);
				endJeff.addEventListener(TouchEvent.TOUCH_END, decisionRollOut);
				endJeff.addEventListener(TouchEvent.TOUCH_TAP, jumpToJeff);
				
				endChana.addEventListener(TouchEvent.TOUCH_BEGIN, decisionRollOver);
				endChana.addEventListener(TouchEvent.TOUCH_END, decisionRollOut);
				endChana.addEventListener(TouchEvent.TOUCH_TAP, jumpToChana);
				
				endVon.addEventListener(TouchEvent.TOUCH_BEGIN, decisionRollOver);
				endVon.addEventListener(TouchEvent.TOUCH_END, decisionRollOut);
				endVon.addEventListener(TouchEvent.TOUCH_TAP, jumpToVon);
			} else {
				endJeff.addEventListener(MouseEvent.MOUSE_OVER, decisionRollOver);
				endJeff.addEventListener(MouseEvent.MOUSE_OUT, decisionRollOut);
				endJeff.addEventListener(MouseEvent.CLICK, jumpToJeff);
				
				endChana.addEventListener(MouseEvent.MOUSE_OVER, decisionRollOver);
				endChana.addEventListener(MouseEvent.MOUSE_OUT, decisionRollOut);
				endChana.addEventListener(MouseEvent.CLICK, jumpToChana);
				
				endVon.addEventListener(MouseEvent.MOUSE_OVER, decisionRollOver);
				endVon.addEventListener(MouseEvent.MOUSE_OUT, decisionRollOut);
				endVon.addEventListener(MouseEvent.CLICK, jumpToVon);
			}
		}
		
		private function decisionRollOut(e:*):void {
			setEndFrames();
		}
		
		private function decisionRollOver(e:*):void {
			Log.USE_LOG && Log.logmsg("ROLL OVER");
			(e.target as MovieClip).gotoAndStop(2);
		}
		
		private function setEndFrames():void {
			if (!selectionStatus[0]) {
				endJeff.gotoAndStop(1);
			} else {
				endJeff.gotoAndStop(3);
			}
			if (!selectionStatus[1]) {
				endChana.gotoAndStop(1);
			} else {
				endChana.gotoAndStop(3);
			}
			if (!selectionStatus[2]) {
				endVon.gotoAndStop(1);
			} else {
				endVon.gotoAndStop(3);
			}
		}
		
		private function jumpToVon(e:*):void {
			selectionStatus[2] = true;
			startVideoAt = rightDecisionStart;
			endVideoAt = rightDecisionEnd;
			track("Decision Von");
			makeDecisionJump();
		}
		
		private function jumpToChana(e:*):void {
			selectionStatus[1] = true;
			startVideoAt = midDecisionStart;
			endVideoAt = midDecisionEnd;
			track("Decision Chana");
			makeDecisionJump();
		}
		
		private function jumpToJeff(e:*):void {
			selectionStatus[0] = true;
			startVideoAt = leftDecisionStart;
			endVideoAt = leftDecisionEnd;
			track("Decision Jeff");
			makeDecisionJump();
		}
		
		private function makeDecisionJump():void {
			decisionMade = true;
			
			leftGripPlaceholder.x = sliderLeftFreezePos;
			rightGripPlaceholder.x = sliderRightFreezePos;
			
			// Set the state.
			setState(STATE_EXPERIENCE);
		}
		
		private function replayExperience(e:MouseEvent = null):void {
			decisionMade = false;
			startVideoAt = 0;
			track("Replay");
			setState(STATE_EXPERIENCE);
		}
		
		/**********************************************************
		 * MOUSE EVENTS
		 **********************************************************/
		
		private function setCursorPointerFaded(e:MouseEvent = null):void {
			if (Mouse.cursor != CURSOR_CLOSED.toString()) {
				Mouse.cursor = CURSOR_POINT + CURSOR_FADED;
			}
		}
		
		private function setCursorPointer(e:MouseEvent = null):void {
			if (Mouse.cursor != CURSOR_CLOSED.toString()) {
				Mouse.cursor = CURSOR_POINT.toString();
			}
		}
		
		private function setCursorHand(e:MouseEvent = null):void {
			if (isFrozen) {
				setCursorPointer(null);
			} else if (!sliderLeftDragActive && !sliderRightDragActive) {
				Mouse.cursor = CURSOR_OPEN.toString();
			}
		}
		
		private function handleTouchDown(e:TouchEvent):void {
			// Log.USE_LOG && Log.logmsg("DOWN --- PRIMARY: " + e.isPrimaryTouchPoint + " - ID: " + e.touchPointID + " - Curr IDs: " + firstTouchId + "/" + secondTouchId + " - ");
			if (e.isPrimaryTouchPoint) {
				// Do normal mouse functions.
				handleDown(e.stageX, e.stageY);
			}
			
			// Detect multi-touches so multiple masks can be moved.
			if (firstTouchId == -1) {
				firstTouchId = e.touchPointID;
				touchPointPrev[0] = touchPointCurr[0] = e.stageX;
				if (secondTouchOn != 2 && rightSliderContainer.hitTestPoint(e.stageX, e.stageY, true) && allowDrag.y == 1) {
					// Touching right mask.
					firstTouchOn = 2;
				} else if (secondTouchOn != 1 && leftSliderContainer.hitTestPoint(e.stageX, e.stageY, true) && allowDrag.x == 1) {
					// Touching left mask.
					firstTouchOn = 1;
				} else {
					// Not touching a mask. Do nothing.
					firstTouchOn = 0;
				}
			} else if (secondTouchId == -1) {
				// Only acknowledge a second touch.
				secondTouchId = e.touchPointID;
				touchPointPrev[1] = touchPointCurr[1] = e.stageX;
				if (firstTouchOn != 2 && rightSliderContainer.hitTestPoint(e.stageX, e.stageY, true) && allowDrag.y == 1) {
					// Touching right mask.
					secondTouchOn = 2;
				} else if (firstTouchOn != 1 && leftSliderContainer.hitTestPoint(e.stageX, e.stageY, true) && allowDrag.x == 1) {
					// Touching left mask.
					secondTouchOn = 1;
				} else {
					// Not touching a mask.
					secondTouchOn = 0;
				}
			}
		}
		
		private function handleTouchUp(e:TouchEvent):void {
			if (e.touchPointID == firstTouchId) {
				firstTouchId = -1;
			} else if (e.touchPointID == secondTouchId) {
				secondTouchId = -1;
				secondTouchOn = 0;
			}
			if (firstTouchId == -1 && secondTouchId == -1) {
				handleUp(e.stageX, e.stageY);
			}
		}
		
		private function handleTouchMove(e:TouchEvent):void {
			// Only use the two points.
			if (e.touchPointID == firstTouchId) {
				// Move point 1.
				touchPointCurr[0] = e.stageX;
			} else if (e.touchPointID == secondTouchId) {
				// Move point 2.
				touchPointCurr[1] = e.stageX;
			}
		}
		
		private function handleMouseDown(e:MouseEvent):void {
			handleDown(e.stageX, e.stageY);
		}
		
		private function handleMouseUp(e:MouseEvent):void {
			handleUp(e.stageX, e.stageY);
		}
		
		private function handleDown(stageX:Number, stageY:Number):void {
			mouseIsDown = true;
			prevMouse.x = stageX;
			prevMouse.y = stageY;
			
			if (!isFrozen) {
				if (pausePlayButton.hitTestPoint(stageX, stageY, true)) {
					// Pause button was clicked. Do nothing.
					return;
				} else if (progressHolder.visible && progressHolder.alpha > 0 && progressHolder.hitTestPoint(stageX, stageY, true)) {
					// Only activate progressDrag if the progressHolder is visible.
					progressDragActive = true;
				} else if (
					stageY >= stageTop &&
					stageY <= stageTop + stageH - timelineHeightMax
				) {
					if (leftSliderContainer.hitTestPoint(stageX, stageY, true) && allowDrag.x == 1) {
						GTweener.removeTweens(leftGripPlaceholder);
						Mouse.cursor = CURSOR_CLOSED.toString();
						sliderLeftDragActive = true;
						gripMouseX = stageX;
						promptTime = PROMPT_WAIT_TIME_MS;
						
						TweenUtil.fadeOut(leftSliderContainer.instruction);
						TweenUtil.fadeOut(rightSliderContainer.instruction);
					}
					if (rightSliderContainer.hitTestPoint(stageX, stageY, true) && allowDrag.y == 1) {
						GTweener.removeTweens(rightGripPlaceholder);
						Mouse.cursor = CURSOR_CLOSED.toString();
						sliderRightDragActive = true;
						gripMouseX = stageX;
						promptTime = PROMPT_WAIT_TIME_MS;
						
						TweenUtil.fadeOut(leftSliderContainer.instruction);
						TweenUtil.fadeOut(rightSliderContainer.instruction);
					}
				}
			}
		}
		
		private function handleUp(stageX:Number, stageY:Number):void {
			mouseIsDown = false;
			if (playState == STATE_LOGO) {
				// Skip the logo.
				playTimer = NFB_OUT;
				nfbtargetAlpha = 0;
			} else if (playState == STATE_TITLE) {
				// Skip the title fade.
				TweenUtil.removeTweensFromObject(blackout);
				TweenUtil.removeTweensFromObject(menuTitle);
				TweenUtil.removeTweensFromObject(menuSubTitle);
				blackout.visible = menuTitle.visible = menuSubTitle.visible = true;
				blackout.alpha = 0.7;
				menuTitle.alpha = menuSubTitle.alpha = 1
				onTitleFinished();
			} else if (sliderLeftDragActive || sliderRightDragActive) {
				// Released a mask.
				if (stageY < stageTop + stageH && stageY >= stageTop + stageH - timelineHeightMax) {
					ptH = timelineHeightMax;
					SetSectionClips(1);
				}
				Mouse.cursor = CURSOR_OPEN.toString();
				
				if (!useTouch) {
					if (sliderLeftDragActive) {
						// Move grip based on mouse velocity. Of course, limit this movement to the max and min places it can go.
						TweenUtil.moveEase(
							leftGripPlaceholder, 
							Math.min(mainW - maskPadding - maskSpacing, Math.max(maskPadding, leftGripPlaceholder.x + (prevMouseXVel * 2)))
						);
					} else {
						// Move grip based on mouse velocity. Of course, limit this movement to the max and min places it can go.
						TweenUtil.moveEase(
							rightGripPlaceholder, 
							Math.min(mainW - maskPadding, Math.max(maskPadding + maskSpacing, rightGripPlaceholder.x + (prevMouseXVel * 2)))
						);
					}
				}
				
				resetDrag();
			} else {
				if (pausePlayButton.hitTestPoint(stageX, stageY, true)) {
					// Released the pausePlayButton. You know what to do.
					toggleMoviePaused();
				} else if ((progressDragActive && stageY > stageH * 3 / 4) && navigationButton.alpha < 1) {
					// Released the progress bar directly. Seek.
					var distFromLeft:Number = stageX - progressBarStartX;
					var desiredRatio:Number = distFromLeft / (stageW - TIMELINE_PADDING - progressBarStartX);
					var desiredTime:Number = videoDuration * desiredRatio;
					
					videoPlayer.cancelFading();
					
					if (decisionMade) {
						// Decision was made. Currently beyond decisionTime.
						if (desiredTime <= decisionTime) {
							// Seek back to before decision.
							decisionMade = false;
							track("Seek to " + (desiredTime | 0));
							videoPlayer.seek(desiredTime);
						} else {
							// Seek within decision segment. Gotta do a little math here.
							var decisionRatio:Number = decisionTime / videoDuration;
							var percentile:Number = (desiredRatio - decisionRatio) / (1 - decisionRatio);
							track("Seek to " + ((startVideoAt + (endVideoAt - startVideoAt) * percentile) | 0));
							videoPlayer.seek(startVideoAt + (endVideoAt - startVideoAt) * percentile);
						}
					} else {
						// Normal seek. Don't go past desiredTime.
						track("Seek to " + (Math.min(desiredTime, decisionTime) | 0));
						videoPlayer.seek(Math.min(desiredTime, decisionTime));
						if (desiredTime >= decisionTime && !isFrozen) {
							// Video hit the decision time. Reset decision state.
							setState(STATE_DECISION);
						}
					}
				}
				progressDragActive = false;
			}
		}
		
		private function resetDrag():void {
			sliderLeftDragActive = false;
			sliderRightDragActive = false;
			leftSliderContainer.stopDrag();
			rightSliderContainer.stopDrag();
		}
		
		/**********************************************************
		 * PARSING DATA
		 **********************************************************/
		
		public function parseMediaData(videoData:XMLList):void {
			var videos:Object = {}, data:MediaData;
			for each (var video:XML in videoData.*) {
				data = new MediaData();
				if (video.@url && video.@url != undefined && video.@url != "") {
					data.url = FileUtil.getFileUrl(video.@url);
				} else {
					// No main URL. Instead get multiple segments.
					data.segments = new Vector.<MediaSegment>();
					var segment:MediaSegment;
					for each(var segmentData:XML in video.segments.*) {
						segment = new MediaSegment({
							name: segmentData.@name,
							url: FileUtil.getFileUrl(segmentData.@url),
							start: segmentData.@start,
							next: segmentData.@next
						});
						data.segments.push(segment);
					}
					if (data.segments.length > 0) {
						data.currentSegment = data.segments[0];
					}
				}
				data.fallbackUrl = FileUtil.getFileUrl(video.@fallback);
				data.loadType = video.@loadtype;
				data.width = video.@width;
				data.height = video.@height;
				data.extraData = video;
				data.crossdomainUrl = video.@crossdomain;
				if (video.@crossdomain) {
					Security.loadPolicyFile(video.@crossdomain);
				}
				videos[video.@id] = data;
				//Log.USE_LOG && Log.logmsg("ADD VIDEO : " + video.@id + ": " + data.url + " - " + data.segments);
			}
			Strings.mediaData = videos;
		}
		
		private function setupInitialLoadData():void {
			Log.USE_LOG && Log.logmsg("Setup initial load media data");
			addEventListener(MainPlayerEvent.LOAD_SUCCEEDED, onMenuDone);
			menuVideoData = Strings.getMediaData(Strings.VIDEO_MENU);

			// TODO: Use this to determine average bandwidth from loading menu video.
			//addEventListener(Event.ENTER_FRAME, onUpdateBandwidth);
		}
		
		private function onMenuDone(e:MainPlayerEvent):void {
			Log.USE_LOG && Log.logmsg(" - Menu vid loaded...");
			
			// Get initial average bandwidth rate. We can use this to help estimate stream loadtime.
			//removeEventListener(Event.ENTER_FRAME, onUpdateBandwidth);
			if (bandwidthArray.length > 0) {
				avgBandwidth = 0;
				for (var i:int = bandwidthArray.length - 1; i >= 0; i--) {
					avgBandwidth += bandwidthArray[i];
				}
				avgBandwidth /= bandwidthArray.length;
			}
			
			updateLoadScreen(1);
			loadedCount++;
			
			removeEventListener(MainPlayerEvent.LOAD_SUCCEEDED, onMenuDone);
			addEventListener(MainPlayerEvent.LOAD_SUCCEEDED, onIntroDone);
			introLoopMediaData = Strings.getMediaData(Strings.AUDIO_INTRO_LOOP);
		}
		
		private function onIntroDone(e:MainPlayerEvent):void {
			Log.USE_LOG && Log.logmsg(" - Audio loop loaded...");
			
			updateLoadScreen(1);
			loadedCount++;
			
			removeEventListener(MainPlayerEvent.LOAD_SUCCEEDED, onIntroDone);
		}
		
		private function onUpdateBandwidth(e:Event):void {
			if (bandwidthArray.length > 10) {
				bandwidthArray.shift();
			}
			var bandwidth:Number = videoPlayer.bandwidth;
			if (bandwidth == 0) { return; }
			
			bandwidthArray.push(videoPlayer.bandwidth);
			Log.USE_LOG && Log.logmsg("Loading... " + bandwidthArray);
		}
		
		/**********************************************************
		 * STATE CHANGING
		 **********************************************************/
		
		private function onTitleFinished():void {
			// Title is finished. Check language.
			if (!Strings.lang || Strings.lang == "") {
				// No default language.
				setState(STATE_LANG_SELECT);
			} else {
				// Skip language selection screen.
				langSelected(Strings.lang);
				if (!Strings.load || Strings.load == "") {
					setState(STATE_LOAD_SELECT);
				} else {
					loadSelectedVideo(Strings.load);
				}
			}

		}
		
		private function selectLanguage(e:MouseEvent):void {
			switch (e.currentTarget) {
				case englishButton:
					langSelected(Strings.LANG_EN);
					break;
				case frenchButton:
					langSelected(Strings.LANG_FR);
					break;
				case khmerButton:
					langSelected(Strings.LANG_KH);
					break;
				default:
					langSelected(Strings.LANG_EN);
			}
			if (!Strings.load || Strings.load == "") {
				setState(STATE_LOAD_SELECT);
			} else {
				loadSelectedVideo(Strings.load);
			}
		}
		
		private function selectLoadType(e:MouseEvent):void {
			// TODO: Display load id buttons.
			if (e.currentTarget == streamButton) {
				displayMenuButton(fastButton);
				displayMenuButton(slowButton);
			} else {
				hideMenuButton(fastButton);
				hideMenuButton(slowButton);
				
				// Download links to download app page.
				dispatchEvent(new MainPlayerEvent(MainPlayerEvent.DOWNLOAD_APP));
				
				// Download button plays progressive video. TESTING ONLY.
				//loadSelectedVideo(Strings.VIDEO_MAIN);
			}
		}
		
		private function selectStreamLoad(e:MouseEvent):void {
			track("Stream Bandwidth: " + (e.currentTarget == fastButton ? "LOW" : "HIGH"));
			loadSelectedVideo("stream_" + (e.currentTarget == fastButton ? Strings.VIDEO_FAST : Strings.VIDEO_SLOW) + "_" + lang);
		}
		
		private function canBranchOffState():Boolean {
			return !(playState == STATE_LOAD || playState == STATE_LOGO || playState == STATE_TITLE);
		}
		
		public function startOver():void {
			if (canBranchOffState()) { setState(STATE_TITLE); }
		}
		
		public function showAbout():void {
			if (canBranchOffState() && lang != null) { setState(STATE_ABOUT); }
		}
		
		public function showCredits():void {
			if (canBranchOffState()) { setState(STATE_CREDITS); }
		}
		
		public function showRelated():void {
			if (canBranchOffState()) { setState(STATE_RELATED); }
		}
		
		public function setLanguage(lang:String):void {
			langSelected(lang);
		}
		
		private function onClickAbout(e:MouseEvent = null):void {
			if (canBranchOffState()) { setState(STATE_ABOUT); }
		}
		
		private function onClickCredits(e:MouseEvent = null):void {
			if (canBranchOffState()) { setState(STATE_CREDITS); }
		}
		
		private function onClickRelated(e:MouseEvent = null):void {
			if (canBranchOffState()) { setState(STATE_RELATED); }
		}
		
		private function onClickCloseCredits(e:MouseEvent = null):void {
			if (playState != STATE_CREDITS) { return; }
			setState(prevState);
		}
		
		public function showNavigation():void {
			// Clicked navigation button. Show the navigation.
			if (playState == STATE_EXPERIENCE) {
				TweenUtil.fadeIn(progressHolder, .2);
				TweenUtil.fadeIn(pausePlayButton, .2);
				TweenUtil.fadeIn(scrub, .2);
				TweenUtil.fadeIn(sectionLinkContainer, .2);
			}
		}
		
		private function onClickNavigation(e:MouseEvent = null):void {
			showNavigation();
		}
		
		private function langSelected(lang:String):void {
			this.lang = lang;
			
			menuTitle.gotoAndStop(lang);
			menuSubTitle.gotoAndStop(lang);
			menuLanguage.gotoAndStop(lang);
			beginButton.gotoAndStop(lang);
			downloadButton.gotoAndStop(lang);
			streamButton.gotoAndStop(lang);
			fastButton.gotoAndStop(lang);
			slowButton.gotoAndStop(lang);
			aboutButton.gotoAndStop(lang);
			creditsButton.gotoAndStop(lang);
			jeffButton.gotoAndStop(lang);
			chanaButton.gotoAndStop(lang);
			vonButton.gotoAndStop(lang);
			replayButton.gotoAndStop(lang);
			navigationButton.gotoAndStop(lang);
			leftSliderContainer.instruction.gotoAndStop(lang);
			rightSliderContainer.instruction.gotoAndStop(lang);
			
			loadScreen.setLanguage(lang);
			creditsScreen.setLanguage(lang);
			
			if (lang == "fr") {
				aboutScreen.setText(Strings.aboutTextFr, lang);
			} else if (lang == "kh") {
				aboutScreen.setText(Strings.aboutTextKh, lang);
			} else {
				aboutScreen.setText(Strings.aboutTextEn, lang);
			}
			aboutScreen.setImages(Strings.aboutImages, lang);
		}
		
		private function loadSelectedVideo(id:String):void {
			// Setup the main video data.
			//Log.USE_LOG && Log.logmsg("LOAD VIDEO: " + id);
			mainVideoData = Strings.getMediaData(id);
			
			// With main selected, enter tutorial mode.
			setState(STATE_TUTORIAL);
		}
		
		private function startExperience(e:MouseEvent):void {
			Log.USE_LOG && Log.logmsg("START EXPERIENCE");
			allowDrag.x = allowDrag.y = 1;
			
			leftSliderContainer.mouseOff();
			rightSliderContainer.mouseOff();
			
			menuHolder.visible = false;
			
			vidHolderLeft.visible = true;
			vidHolderRight.visible = true;
			
			leftSliderContainer.hideInst();
			rightSliderContainer.hideInst();
			
			// Check for sync start.
			if (videoLoaded) {
				bufferClip.visible = false;
				
				if (!firstRun) {
					firstRun = true;
					pausePlayButton.gotoAndStop(2);
					SetSectionClips(2);
				}
			}
			
			// Start at the beginning every time user clicks "begin".
			startVideoAt = 0;
			track("Start Video");
			track("0%");
			
			resize(stageW, stageH);
			
			decisionMade = false;
			setState(STATE_EXPERIENCE);
		}
		
		private function timelineJump(e:MouseEvent):void {
			for each (var i:SectionLink in sectionLinks) {
				var mc:MovieClip = i.clip;
				if (mc.hitTestPoint(e.stageX, e.stageY)) {
					videoPlayer.seek(i.time);
					videoPlayer.cancelFading();
					if (i.time == decisionTime) {
						// Clicked "conclusion button". Set the state.
						setState(STATE_DECISION);
					} else if (decisionMade && i.time < decisionTime) {
						// Seek back to before decision.
						decisionMade = false;
					} else if (!decisionMade && i.time >= decisionTime && !isFrozen) {
						// Video hit the decision time. Reset decision state.
						setState(STATE_DECISION);
					}
					break;
				}
			}
		}
		
		private function streamMetaData(metadata:Object):void {
			//videoDuration = metadata.duration;
			Log.USE_LOG && Log.logmsg("MetaData orig: " + metadata.duration);
		}
		
		private function toggleMoviePaused():void {
			Log.USE_LOG && Log.logmsg('TOGGLE PAUSE');
			if (pausePlayButton.currentFrame == 3) {
				videoPlayer.resume();
				pausePlayButton.gotoAndStop(2);
			} else {
				videoPlayer.pause();
				pausePlayButton.gotoAndStop(3);
			}
		}
		
		private function displayMenuButton(button:MovieClip):void {
			button.visible = true;
			button.alpha = 0;
			button.mouseEnabled = true;
			button.mouseChildren = true;
			button.parent.setChildIndex(button, 0);
			TweenUtil.fadeIn(button, 1);
		}
		
		private function hideMenuButton(button:MovieClip):void {
			button.visible = false;
			button.mouseEnabled = false;
			button.mouseChildren = false;
			TweenUtil.fadeOut(button);
		}
		
		private function setupMenuTitle():void {
			menuHolder.visible = true;
			menuHolder.alpha = 1;
			
			menuTitle.visible = true;
			menuTitle.alpha = 1;
			menuSubTitle.visible = true;
			menuSubTitle.alpha = 1;
			menuLanguage.visible = false;
			menuLanguage.alpha = 0;
			
			GTweener.removeTweens(blackout);
			GTweener.removeTweens(menuTitle);
			GTweener.removeTweens(menuSubTitle);
			GTweener.removeTweens(menuLanguage);
			
			// Hide all the buttons.
			var child:Sprite;
			for (var i:int = menuOptions.numChildren - 1; i >= 0; i--) {
				child = menuOptions.getChildAt(i) as Sprite;
				child.visible = false;
				child.mouseEnabled = false;
				child.mouseChildren = false;
				GTweener.removeTweens(child);
			}
		}
		
		/**********************************************************
		 * UPDATE
		 **********************************************************/
		
		/** Universal update. */
		private function update(e:Event = null):void {
			var time:Number = new Date().time;
			
			// Quick and easy MouseMove detection.
			mouseMoved = prevMouse.x != mouseX || prevMouse.y != mouseY;
			
			// --- UPDATE MASKS
			var leftPos:Number = leftGripPlaceholder.x; 
			var rightPos:Number = rightGripPlaceholder.x;
			
			// Update mask positions based on mouse or touch velocity.
			if (useTouch) {
				// Using touch.
				var pointDistA:Number = touchPointCurr[0] - touchPointPrev[0];
				var pointDistB:Number = touchPointCurr[1] - touchPointPrev[1];

				// Uses multi-touch. Possibly two touch sources. Move both masks accordingly.2
				if (firstTouchOn == 1 && pointDistA != 0) {
					// Move left touch based on swipe movement.
					prevTouchLeftVel = pointDistA;
				} else if (secondTouchOn == 1 && pointDistB != 0) {
					// Move left touch based on swipe movement.
					prevTouchLeftVel = pointDistB;
				} else {
					// Ease a bit.
					prevTouchLeftVel *= .5;
					if (prevTouchLeftVel < 0.1 && prevTouchLeftVel > -0.1) {
						prevTouchLeftVel = 0;
					}
				}
				
				leftPos = Math.max(maskPadding, Math.min(leftPos + (prevTouchLeftVel / mainContainer.scaleX), mainW - maskPadding - maskSpacing));
				rightPos = Math.max(leftPos + maskSpacing, rightPos);
				
				// Uses multi-touch. Possibly two touch sources. Move both masks accordingly.
				if (firstTouchOn == 2 && pointDistA != 0) {
					// Move left touch based on swipe movement.
					prevTouchRightVel = pointDistA;
				} else if (secondTouchOn == 2 && pointDistB != 0) {
					// Move left touch based on swipe movement.
					prevTouchRightVel = pointDistB;
				} else {
					prevTouchRightVel *= .5;
					if (prevTouchRightVel < 0.1 && prevTouchRightVel > -0.1) {
						prevTouchRightVel = 0;
					}
				}
				
				rightPos = Math.min(mainW - maskPadding, Math.max(maskPadding + maskSpacing, rightPos + (prevTouchRightVel / mainContainer.scaleX)));
				leftPos = Math.min(rightPos - maskSpacing, leftPos);
				
				// Reset values so if no move update later, mask doens't keep moving.
				touchPointPrev[0] = touchPointCurr[0];
				touchPointPrev[1] = touchPointCurr[1];
			} else if (mouseMoved) {
				// Mouse moved. Update velocity.
				prevMouseXVel = (mouseX - prevMouse.x) / mainContainer.scaleX;
				
				// Prevent the user from being able to send the grips off the edge.
				if (sliderLeftDragActive) {
					// Move the grips if the mouse is dragging.
					leftPos += prevMouseXVel;
					leftPos = Math.max(maskPadding, Math.min(leftPos, mainW - maskPadding - maskSpacing));
					rightPos = Math.max(leftPos + maskSpacing, rightPos);
				} else if (sliderRightDragActive) {
					// Move the grips if the mouse is dragging.
					rightPos += prevMouseXVel;
					rightPos = Math.min(mainW - maskPadding, Math.max(maskPadding + maskSpacing, rightPos));
					leftPos = Math.min(rightPos - maskSpacing, leftPos);
				}
			} else if (prevMouseXVel > 0) {
				// Don't immediately dismiss mouse velocity.
				prevMouseXVel *= .5;
				if (prevMouseXVel < 0.1 && prevMouseXVel > -0.1) {
					prevMouseXVel = 0;
				}
			}
			
			// Prevent tweened movement from overlapping edges.
			if (GTweener.getTweens(leftGripPlaceholder).length > 0) {
				rightPos = Math.max(leftPos + maskSpacing, rightPos);
			}
			if (GTweener.getTweens(rightGripPlaceholder).length > 0) {
				leftPos = Math.min(rightPos - maskSpacing, leftPos);
			}
			
			// Physically set the placeholder positions, even with tweens.
			leftGripPlaceholder.x = leftPos;
			rightGripPlaceholder.x = rightPos;
			
			// If there was a position change, move the masks in the video player.
			if (leftPos != leftSliderContainer.x) {
				leftSliderContainer.x = leftPos;
				videoPlayer.maskLeftPos = leftPos;
			}
			if (rightPos != rightSliderContainer.x) {
				rightSliderContainer.x = rightPos;
				videoPlayer.maskRightPos = rightPos;
			}
			
			if (playState == STATE_TUTORIAL) {
				// Alright, we're in tutorial mode. Make the masks move a touch on over. Shows user it's interactable.
				if (leftSliderContainer.hitTestPoint(mouseX, mouseY, true)) {
					// GripLeft is highlighted.
					if (!leftSliderContainer.mouseOver && !sliderLeftDragActive && mouseMoved) {
						leftSliderContainer.mouseOn();
					} else if (rightSliderContainer.mouseOver) {
						rightSliderContainer.mouseOff();	
					}
				} else if (rightSliderContainer.hitTestPoint(mouseX, mouseY, true)) {
					// GripRight is highlighted.
					if (!rightSliderContainer.mouseOver && !sliderRightDragActive && mouseMoved) {
						rightSliderContainer.mouseOn();
					} else if (leftSliderContainer.mouseOver) {
						leftSliderContainer.mouseOff();
					}
				} else {
					// Nothing's highlighted.
					if (leftSliderContainer.mouseOver && !sliderLeftDragActive) {
						leftSliderContainer.mouseOff();
					} else if (rightSliderContainer.mouseOver && !sliderRightDragActive) {
						rightSliderContainer.mouseOff();
					}
				}
			}
			
			// Update based on play state.
			switch (playState) {
				case STATE_LOGO:
					// Update the alpha.
					if (playTimer > NFB_OUT && nfblogo.alpha <= 0) {
						// Logo finished fading out. Next state.
						setState(STATE_TITLE);
					} else if (nfblogo.alpha < nfbtargetAlpha) {
						nfblogo.alpha = Math.min(nfbtargetAlpha, nfblogo.alpha + 0.025);
					} else if (nfblogo.alpha > nfbtargetAlpha) {
						nfblogo.alpha = Math.max(0, nfblogo.alpha - 0.025);
					}
					break;
				case STATE_TITLE:
				case STATE_LANG_SELECT:
				case STATE_LOAD_SELECT:
				case STATE_ABOUT:
				case STATE_RELATED:
				case STATE_END:
					// Simply update the video player. That's it.
					videoPlayer.update();
					break;
				case STATE_CREDITS:
					videoPlayer.update();
					creditsScreen.update();
					break;
				case STATE_TUTORIAL:
					// Update the video player, but do a few more things.
					videoPlayer.update();
					
					// Tutorial checks mask position and autocompletes when the user understands how they work.
					if (promptTime > 0 && !sliderLeftDragActive && !sliderRightDragActive) {
						promptTime -= time - prevTime;
						if (promptTime <= 0) {
							promptTime = 0;
							
							// Show instructions on vidHolders 1 and 3. This will make them move as you slide.
							leftSliderContainer.instruction.alpha = rightSliderContainer.instruction.alpha = 0;
							TweenUtil.fadeIn(leftSliderContainer.instruction, 1);
							TweenUtil.fadeIn(rightSliderContainer.instruction, 1);
						}
					}
					break;
				case STATE_EXPERIENCE:
					if (isPaused) { return; }
					
					// Check if video hit decision time or endVideoAt time.
					var timeRounded:Number = (videoPlayer.time | 0);
					
					if (decisionMade) {
						// In the decision section of the video (past conclusion).
						if (timeRounded >= endVideoAt && !isFrozen) {
							// Video hit the end of the decision segment. End the video.
							track("100%");
							setState(STATE_END);
						} else if (timeRounded + MENU_FADE_TIME >= endVideoAt && videoPlayer.isFading) {
							// Close to the end, but not yet there. Fade effect to the end screen.
							videoPlayer.fadeVideo(Strings.VIDEO_MENU, 0, 1, endVideoAt - timeRounded);
						}
					} else {
						if (timeRounded >= decisionTime && !isFrozen) {
							// Video hit the decision time. Reset decision state.
							track("Decision Start");
							setState(STATE_DECISION);
						}
					}
					
					// Render the three video segments.
					videoPlayer.update();
					
					if (mouseMoved) {
						// Only fade in the progress holder if mouse movement is at its level.
						if (mouseY >= progressHolder.y) {
							if ((progressHolder.alpha < 1 && progressFadeOutTime <= 0) || !progressHolder.visible) {
								if (useTouch) {
									TweenUtil.fadeIn(navigationButton, .2);
								} else {
									// Fade timeline back in.
									TweenUtil.fadeIn(progressHolder, .2);
									TweenUtil.fadeIn(pausePlayButton, .2);
									TweenUtil.fadeIn(scrub, .2);
									TweenUtil.fadeIn(sectionLinkContainer, .2);
								}
							}
							progressFadeOutTime = PROGRESS_FADE_OUT_TIME;
						}
					} else if (progressFadeOutTime > 0) {
						// Waiting to fade out.
						progressFadeOutTime -= (time - prevTime);
						if (progressFadeOutTime <= 0) {
							// Enough time has passed. Fade out the progress bar.
							if (useTouch) {
								TweenUtil.fadeOut(navigationButton);
							}
							TweenUtil.fadeOut(progressHolder);
							TweenUtil.fadeOut(pausePlayButton);
							TweenUtil.fadeOut(scrub);
							TweenUtil.fadeOut(sectionLinkContainer);
						}
					}
					
					// Update the progress bar, if visible. Saves some processor if just playing.
					if (progressHolder.alpha > 0) {
						updateProgressBar(time - prevTime);
					}
					break;
			}
			
			// --- UPDATE CURSOR
			var top:Number = stageTop + stageH;
			if (mouseY >= top || mouseY <= stageTop) {
				// Cursor is on a nav bar. Pointer.
				setCursorPointer(null);
			} else if (playState == STATE_EXPERIENCE) {
				if (mouseY > (top - TIMELINE_PADDING - timelineHeightMax - (sectionLinkContainer.height * .5))) {
					// Cursor is on the timeline. Pointer and highlight progress bar.
					if (mouseMoved) {
						// Mouse moved. Reset the timer.
						timelineFade = TIMELINE_FADE_TIME;
						if (ptH != timelineHeightMax) {
							ptH = timelineHeightMax;
							SetSectionClips(1);
						}
					}
					setCursorPointer(null);
				} else if (leftGripPlaceholder.hitTestPoint(mouseX, mouseY, true) || rightGripPlaceholder.hitTestPoint(mouseX, mouseY, true)) {
					// Cursor is touching a mask.
					timelineFade = 0;
					if (ptH != timelineHeightMin) {
						ptH = timelineHeightMin;
						SetSectionClips(2);
					}
					setCursorHand(null);
				} else {
					// Not touching anything.
					timelineFade = 0;
					if (ptH != timelineHeightMin) {
						ptH = timelineHeightMin;
						SetSectionClips(2);
					}
					setCursorPointerFaded(null);
				}
			} else if (playState == STATE_DECISION) {
				// Cursor is on decision buttons.
				if (selectionHolder.hitTestPoint(mouseX, mouseY, true)) {
					setCursorPointer(null);
				} else {
					setCursorPointerFaded(null);
				}
			} else {
				// Do nothing. The buttons and such will handle the cursor.
				if (leftSliderContainer.hitTestPoint(mouseX, mouseY, true) || rightSliderContainer.hitTestPoint(mouseX, mouseY, true)) {
					// Cursor is touching a mask.
					setCursorHand(null);
				} else if (menuOptions.hitTestPoint(mouseX, mouseY, true)) {
					setCursorPointer(null);
				} else {
					setCursorPointerFaded(null);
				}
			}
			
			// Update prevMouse.
			prevMouse.x = mouseX;
			prevMouse.y = mouseY;
			
			// Track positional updates.
			var percentile:Number = videoPlayer.time / videoDuration;
			if (percentile >= .25 && prevStreamPercentile < .25) {
				track("25%");
			} else if (percentile >= .5 && prevStreamPercentile < .5) {
				track("50%");
			} else if (percentile >= .75 && prevStreamPercentile < .75) {
				track("75%");
			}
			prevStreamPercentile = percentile;
			
			prevTime = time;
		}
		
		/** Updates the progress bar for the user. */
		private function updateProgressBar(deltaTime:Number = 0):void {
			// Get the left, right, and bottom edges of the progress bar.
			var padL:Number = progressBarStartX; // Left side of progressbar.
			var padR:Number = stageW - TIMELINE_PADDING; // Right side of progressbar.
			var barWidth:Number = padR - padL;
			var padVM:Number = progressBarStartY; // vertical middle y position of progressbar.
			var halfH:Number = pH / 2;
			var barTop:Number = padVM - halfH;
			var barBot:Number = padVM + halfH;
			
			// Draw full progress bar background.
			progressHolder.graphics.clear();
			progressHolder.graphics.lineStyle(0, 0, 0);
			progressHolder.graphics.beginFill(0xffffff, 0.25);
			progressHolder.graphics.drawRect(padL, barTop, barWidth, pH);
			progressHolder.graphics.endFill();
			
			// Get the progress rectangle length.
			if (progressDragActive) {
				// User is dragging progress bar. Move it around.
				prgPixels = mouseX - padL;
			} else if (videoPlayer.time) {
				if (videoPlayer.time <= decisionTime) {
					// On a normal segment. Get pixels using NetStream time.
					prgPixels = barWidth * (videoPlayer.time / videoDuration);
				} else {
					// On a decision segment. Manually get the segment time.
					var extraSegmentTime:Number = videoDuration - decisionTime;
					var extraSegmentRatio:Number = (videoPlayer.time - startVideoAt) / (endVideoAt - startVideoAt);
					prgPixels = barWidth * ((decisionTime + (extraSegmentTime * extraSegmentRatio)) / videoDuration);
				}
			} else {
				// No video. No progress.
				prgPixels = 0;
			}
			
			// Move scrubber.
			scrub.x = Math.floor(prgPixels + padL);
			scrub.y = barBot;

			// Draw load progress rect.
			var right:Number = barWidth * (videoPlayer.bufferLength / videoDuration);
			progressHolder.graphics.beginFill(0x000000, 0.4);
			progressHolder.graphics.drawRect(padL + prgPixels, barTop, right, pH);
			progressHolder.graphics.endFill();
			
			// Draw progress rect.
			progressHolder.graphics.beginFill(0x000000, 0.6);
			progressHolder.graphics.drawRect(padL, barTop, prgPixels, pH);
			progressHolder.graphics.endFill();

			// Draw horizontal strike-through line.
			progressHolder.graphics.lineStyle(timelineHeightMin, 0xBBBDBF, 0.25);
			progressHolder.graphics.moveTo(padL, padVM);
			progressHolder.graphics.lineTo(padR, padVM);
			
			// Draw vertical end line.
			progressHolder.graphics.lineStyle(1, 0xBBBDBF);
			progressHolder.graphics.moveTo(padR, barTop);
			progressHolder.graphics.lineTo(padR, barBot);
			
			// Draw vertical scrub line.
			progressHolder.graphics.lineStyle((ptH == timelineHeightMax) ? 2 : 1, 0xBBBDBF);
			progressHolder.graphics.moveTo(scrub.x, barTop);
			progressHolder.graphics.lineTo(scrub.x, barBot);
			
			// Show section links based on progressBar state.
			var link:SectionLink;
			if (pH != ptH) {
				// Ease the progressBar to its destination height.
				pH += (ptH - pH) / 4;
				
				// Snap to target if difference is less than 1 and show clips.
				if (Math.abs(ptH - pH) < 1) {
					// Finished. Set section clips and display them again.
					pH = ptH;
				}
			}
			
			// Countdown until automatically fade out.
			if (timelineFade > 0) {
				timelineFade -= deltaTime;
				if (timelineFade <= 0) {
					// Automatically fade out the timeline on inactivity.
					timelineFade = 0;
					ptH = timelineHeightMin;
					SetSectionClips(2);
				}
			}
		}
		
		/**********************************************************
		 * SECTION CLIPS
		 **********************************************************/
		
		private function SetSectionClips(toframe:Number):void {
			scrub.gotoAndStop(toframe);
			for each (var i:SectionLink in sectionLinks) {
				i.gotoAndStop(toframe == 1 ? lang : lang + "-mini");
				
				if (toframe == 2) {
					TweenUtil.fadeOut(i.clip, .5);
				} else {
					TweenUtil.fadeIn(i.clip, .2, 1);
				}
			}
		}
		
		/**********************************************************
		 * STREAM STATUS
		 **********************************************************/
		
		private function onContext3DReady(e:Event):void {
			dispatchEvent(new MainPlayerEvent(MainPlayerEvent.READY_TO_RECEIVE_MEDIA));
		}
		
		private function onIntroLoopLoadComplete(e:Event):void {
			Log.USE_LOG && Log.logmsg("Intro loop load complete.");
			removeEventListener(ProgressEvent.PROGRESS, handleSoundLoadProgress);
			dispatchEvent(new MainPlayerEvent(MainPlayerEvent.LOAD_SUCCEEDED));
		}
		
		private function handleFullyLoaded(e:Event):void {
			Log.USE_LOG && Log.logmsg(" - Load Complete!");
			dispatchEvent(new MainPlayerEvent(MainPlayerEvent.LOAD_COMPLETED));
			loadScreen.removeEventListener(Event.COMPLETE, handleFullyLoaded, false);
			setState(STATE_LOGO);
		}
		
		private function handleMediaLoadError(e:IOErrorEvent):void {
			Log.USE_LOG && Log.logmsg("Media load failed.");
			var type:String, data:MediaData;
			if (e.target == introLoop && !introLoopData.useFallback) {
				introLoopData.useFallback = true;
				
				// introLoop.load doesn't work for some reason. Gotta create a new Sound object on fail.
				introLoop = new Sound(new URLRequest(introLoopData.fallbackUrl));
				introLoop.addEventListener(IOErrorEvent.IO_ERROR, handleMediaLoadError, false, 0, true);
				introLoop.addEventListener(Event.COMPLETE, onIntroLoopLoadComplete, false, 0, true);
			} else {
				// Fallback won't work or there is none. Do something!
				dispatchEvent(new MainPlayerEvent(MainPlayerEvent.LOAD_FAILED, introLoopData));
			}
		}
		
		/** Includes status event from credits. Once finished playing, returns to prevState. */
		private function handleCreditStatus(e:NetStatusEvent):void {
			Log.USE_LOG && Log.logmsg('Credit ' + e.info.level + ': ' + e.info.code);
			if (e.info.code == "NetStream.Play.Stop" || e.info.code == "NetStream.Buffer.Empty" || e.info.code == "NetStream.Buffer.Flush") {
				// Cannot set state directly from a status event. Run a timer instead.
				prevStateTimer.start();
			} else if (e.info.code == "NetStream.Play.Failed" && e.info.level == "status") {
				// Play failed, but not because of an error. Get some more info on this one.
			}
		}
		
		/** Handle status event from menu. Includes looping code. */
		private function handleMenuStatus(e:NetStatusEvent):void {
			Log.USE_LOG && Log.logmsg('Menu ' + e.info.level + ': ' + e.info.code);
			if (e.info.code == "NetStream.Play.Stop" || e.info.code == "NetStream.Buffer.Empty" || e.info.code == "NetStream.Buffer.Flush") {
				videoPlayer.seek(0);
				videoPlayer.resume();
				track("Loop Video");
			} else if (e.info.code == "NetStream.Play.Failed" && e.info.level == "status") {
				// TODO: Play failed, but not because of an error. Get some more info on this one.
				Log.USE_LOG && Log.logmsg("Playback failed. Filetype invalid. Contact administrator.");
			}
		}
		
		/** Handle status event from main video. */
		private function handleMainStatus(e:NetStatusEvent):void {
			Log.USE_LOG && Log.logmsg('Main ' + e.info.level + ': ' + e.info.code);
			//if (e.info.code == "NetStream.Play.Start" && vp2.videoWidth > 0) {
			switch (e.info.code) {
				case "NetStream.Play.Start":
					bufferClip.visible = true;
					videoLoaded = false;
					break;
				case "NetStream.Unpause.Notify":
					bufferClip.visible = false;
					break;
				case "NetStream.SeekStart.Notify":
					bufferClip.visible = false;
					break;
				case "NetStream.Buffer.Full":
					bufferClip.visible = false;
					videoLoaded = true;
					break;
				case "NetStream.Pause.Notify":
					bufferClip.visible = false;
					break;
				case "NetStream.Seek.Complete":
					updateProgressBar(0);
					break;
				case "NetStream.Buffer.Empty":
					bufferClip.visible = true;
					videoLoaded = false;
					break;
				case "NetStream.Play.StreamNotFound":
				case "NetStream.Play.Failed":
					//Log.USE_LOG && Log.logmsg("Failed? What's the URL? : " + mainData.baseStreamUrl + " --- " + mainData.url);
					break;
			}
		}
		
		private function handleMediaLoadFailed(e:VideoPlayerEvent):void {
			var data:MediaData = e.data as MediaData;
			//Log.USE_LOG && Log.logmsg("Alright, load failed. Do we have a fallback? " + data.videoName + " - " + data.fallbackUrl);
			if (data.fallbackUrl && data.fallbackUrl != "") {
				// Setup new video data.
				switch (data.videoName) {
					case Strings.VIDEO_MENU:
						menuVideoData = Strings.getMediaData(data.fallbackUrl);
						break;
					case Strings.VIDEO_MAIN:
						mainVideoData = Strings.getMediaData(data.fallbackUrl);
						break;
				}
				
				// Refresh the state to attempt to play the video again.
				var oldState:int = playState;
				playState = -1;
				setState(oldState);
			} else {
				dispatchEvent(new MainPlayerEvent(MainPlayerEvent.LOAD_FAILED, data));
			}
		}
		
		private function handleMediaLoadSuccess(e:VideoPlayerEvent):void {
			dispatchEvent(new MainPlayerEvent(MainPlayerEvent.LOAD_SUCCEEDED, e.data));
		}
		
		private function handleMediaLoadProgress(e:VideoPlayerEvent):void {
			updateLoadScreen(e.data as Number);
		}
		
		private function handleMediaResized(e:VideoPlayerEvent):void {
			// Move the main video container so it's centered.
			if (mainContainer) {
				var wid:Number = videoPlayer.width;
				var hei:Number = videoPlayer.height;
				
				// Scale the MainContainer accordingly based on videoDisplay.
				mainContainer.scaleX = mainContainer.scaleY = Math.min(
					(stageW / wid),
					(stageH / hei)
				);
				
				// Get the new main container dimensions. Their aspect ratio should match videoDisplay.
				var contWidth:Number = mainContainer.scaleX * wid;
				var contHeight:Number = mainContainer.scaleY * hei;
				
				// Position the main container so it's centered.
				mainContainer.x = (stageW - contWidth) / 2;
				mainContainer.y = stageTop + (stageH - contHeight) / 2;
				
				// Scale and position the selection holder too.
				selectionHolder.scaleX = mainContainer.scaleX;
				selectionHolder.scaleY = mainContainer.scaleY;
				selectionHolder.x = mainContainer.x;
				selectionHolder.y = mainContainer.y;
			}
		}
		
		private function track(s:String):void {
			dispatchEvent(new MainPlayerEvent(MainPlayerEvent.TRACK_ANALYTICS, s));
		}
		
		private function handleSoundLoadProgress(e:ProgressEvent):void {
			updateLoadScreen(e.bytesLoaded / e.bytesTotal);
		}
		
		private function updateLoadScreen(loadProgress:Number):void {
			var ratio:Number = 1 / loadedTotal;
			loadScreen.loadPercent = ((ratio * loadedCount) + (loadProgress * ratio)) * 100;
		}
	}
}
