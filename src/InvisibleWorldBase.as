package {
	import flash.display.Loader;
	import flash.display.LoaderInfo;
	import flash.display.StageAlign;
	import flash.display.StageDisplayState;
	import flash.display.StageScaleMode;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.URLRequest;
	import flash.system.ApplicationDomain;
	import flash.system.Capabilities;
	import flash.system.LoaderContext;
	import flash.system.Security;
	import flash.system.SecurityDomain;
	import flash.text.Font;
	import flash.utils.Timer;
	import flash.utils.getDefinitionByName;
	
	import ca.nfb.interactive.content.BaseNFB;
	import ca.nfb.interactive.content.BotNav;
	import ca.nfb.interactive.data.Strings;
	import ca.nfb.interactive.display.AbstractVideoPlayer;
	import ca.nfb.interactive.display.VideoPlayerBitmapData;
	import ca.nfb.interactive.log.Log;
	import ca.nfb.interactive.performanceprofiling.PerformanceProfiler;
	import ca.nfb.interactive.utils.FileUtil;
	import ca.nfb.interactive.utils.XMLloader;
	import ca.nfb.interactive.videoplayer.MainPlayer;
	import ca.nfb.interactive.videoplayer.events.MainPlayerEvent;

	public class InvisibleWorldBase extends BaseNFB {
		
		// --------------------------------
		// A43: CHANGE THIS VARIABLE TO CHANGE THE APP LANGUAGE.
		public static var language:String = "en";
		// --------------------------------
		
		// Config XML file
		public var configUrl:String = "config.xml";
		public var playerUrl:String = "MainPlayer.swf";
		
		protected var deviceVersion:Number;
		protected var deviceName:String;
		protected var deviceType:String;
		
		protected var timelineHeight:Number = 22;
		protected var navBarHeight:Number = 30;
		
		protected var stageW:Number = 0;
		protected var stageH:Number = 0;
		
		// Original container dimensions. Does not change.
		protected var mainW:int = 992;
		protected var mainH:int = 550;
		
		protected var OUT_OF_FRAMEWORK:Boolean;
		protected var botNav:BotNav;
		protected var useTouch:Boolean = false;
		
		protected var isMuted:Boolean = false;
		protected var isShareExtended:Boolean = false;
		
		// Main video player.
		protected var mainLoader:Loader;
		protected var videoPlayer:AbstractVideoPlayer;
		protected var mediaPlayer:MainPlayer;
		
		protected var errorCheckCount:int = 5;
		
		public function InvisibleWorldBase() {
			super();
			
			// Load the policy file.
			Security.loadPolicyFile("rtmp://wowza.nfb.ca");
			Security.loadPolicyFile("http://wowza.nfb.ca");
			Security.loadPolicyFile("rtmp://wowza.nfb.ca/ralvod");
			Security.loadPolicyFile("http://wowza.nfb.ca/ralvod");
			Security.loadPolicyFile("rtmp://wowza.nfb.ca/ralvod/crossdomain.xml");
			Security.loadPolicyFile("http://wowza.nfb.ca/ralvod/crossdomain.xml");
			Security.loadPolicyFile("http://s334m0dxx0rksm.cloudfront.net/crossdomain.xml");
			
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
			
			// Setup the context and stuff here.
			if (this.parent && this.parent == stage) {
				OUT_OF_FRAMEWORK = true;
				enableOutOfFrameworkTesting();
			} else {
				OUT_OF_FRAMEWORK = false;
			}
		}
		
		//---------------------------------------------------------------------------
		//
		//	Out-of-framework Testing Methods
		//
		//---------------------------------------------------------------------------
		
		/**
		 * 	These methods enable your story to compile without the NFB Framework.  
		 *	Stage properties are used instead of the framework's container properties.
		 *	The story's config.xml file is manually loaded instead of being passed in 
		 *	from the framework.
		 *	A substitute bottom nav bar is displayed to mimic the framework's footer.
		 */
		private function enableOutOfFrameworkTesting():void {
			addEventListener(Event.ADDED_TO_STAGE, initOutOfFramework);
		}
		
		private function initOutOfFramework(e:Event):void {
			Log.USE_LOG && Log.logmsg("Init framework complete!");
			removeEventListener(Event.ADDED_TO_STAGE, initOutOfFramework);
			
			stage.scaleMode = StageScaleMode.NO_SCALE;
			stage.align = StageAlign.TOP_LEFT;
			stage.addEventListener(Event.RESIZE, onResize);
			loadConfig();
		}
		
		/** Start the app. */
		public override function start():void {
			// Referencing external domain data. Allow domain.
			Security.allowDomain("*");
			
			/*
			if (baseURL && baseURL != "") {
				Security.allowDomain(baseURL.match(
					/[^\sw\.@/]([0-9a-zA-Z\-\.]*[0-9a-zA-Z\-]+\.)(de|ca|com|org|net|edu|DE|COM|ORG|NET|EDU)/
				)[0]);
			}
			*/
			
			FileUtil.setBase(baseURL);
			loadConfig();
		}
		
		/** Load the config XML. */
		private function loadConfig():void {
			// Setup controls.
			Log.USE_LOG && Log.logmsg("Load config... " + FileUtil.getFileUrl(configUrl));
			XMLloader.loadXML(FileUtil.getFileUrl(configUrl), onConfigLoaded);
		}
		
		/** Config XML successfully loaded. Store, then start loading player. */
		private function onConfigLoaded(xml:XML):void {
			Log.USE_LOG && Log.logmsg("ConfigXML Loaded. Here's what it looks like: " + FileUtil.getFileUrl(configUrl));
			
			// Load config values.
			configXML = xml;
			
			// Start loading the player.
			loadPlayer();
		}
		
		/** Load the main player. */
		private function loadPlayer():void {
			FileUtil.setBase(baseURL);
			
			Log.USE_LOG && Log.logmsg("Load player... " + FileUtil.getFileUrl(playerUrl));
			
			// Get the main!
			var urlRequest:URLRequest = new URLRequest(FileUtil.getFileUrl(playerUrl));
			mainLoader = new Loader();
			mainLoader.contentLoaderInfo.addEventListener(Event.COMPLETE, onPlayerLoaded);
			mainLoader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onIOError);
			mainLoader.load(urlRequest, new LoaderContext(false, ApplicationDomain.currentDomain, loaderInfo.isURLInaccessible ? SecurityDomain.currentDomain : null));
		}
		
		protected function onPlayerLoaded(e:Event):void {
			Log.USE_LOG && Log.logmsg("Load event complete!");
			
			// Main Player is loaded. Start up all the things.
			var info:LoaderInfo = e.currentTarget as LoaderInfo;
			mediaPlayer = info.content as MainPlayer;
			addChild(mediaPlayer);
			
			mediaPlayer.timelineHeight = timelineHeight;
			
			// Main has all the fonts. Get references.
			Font.registerFont(getDefinitionByName("Arial") as Class);
			Font.registerFont(getDefinitionByName("Standard0756") as Class);
			
			// Add event listeners.
			mediaPlayer.addEventListener(MainPlayerEvent.LOAD_FAILED, onLoadFailed, false, 0, true);
			mediaPlayer.addEventListener(MainPlayerEvent.READY_TO_RECEIVE_MEDIA, onReadyToReceiveMedia, false, 0, true);
			mediaPlayer.addEventListener(MainPlayerEvent.DOWNLOAD_APP, onDownloadApp, false, 0, true);
			mediaPlayer.addEventListener(MainPlayerEvent.TRACK_ANALYTICS, onTrackAnalytics, false, 0, true);
			
			// Parse the XML data first.
			mediaPlayer.parseConfig(configXML);
			
			// Initialize the player.
			mediaPlayer.start(videoPlayer ? videoPlayer : new VideoPlayerBitmapData(stage, mainW, mainH), mainW, mainH);
			
			if (OUT_OF_FRAMEWORK) {
				// Only call animateIn() for out-of-framework testing here, otherwise the 
				// framework will automatically call animateIn() after your story has been 
				// added to the display list.
				animateIn();
			} else {
				// Once assets are prepped, tell the framework that the story is ready.
				// When displayed, it will call animateIn().
				readyToAnimate();
			}
		}
		
		protected function onIOError(e:IOErrorEvent):void {
			// IO Error. Try again?
			Log.USE_LOG && Log.logmsg(e.type + ": " + e.text + " --- " + (e.currentTarget as LoaderInfo).contentType);
			errorCheckCount--;
			if (errorCheckCount <= 0) {
				Log.USE_LOG && Log.logmsg("Sorry, we just can't connect to the player. Check your connection or contact the system admin. " + (e.currentTarget as LoaderInfo).loaderURL + " --- " + (e.currentTarget as LoaderInfo).url);
			} else {
				var timeoutTimer:Timer = new Timer(1000, 1);
				timeoutTimer.addEventListener(TimerEvent.TIMER_COMPLETE, function (e:TimerEvent):void {
					Log.USE_LOG && Log.logmsg("Try again...");
					loadPlayer();
				}, false, 0, true);
				timeoutTimer.start();
			}
		}
		
		/**
		 * 	When your story calls the framework's readyToAnimate() method, the
		 *  the framework adds your story to the display list, resizes it, shows the
		 *	framework's prev/next buttons, hides the framework's loading text, passes
		 * 	configXML data to your story (for your footer link handler methods)
		 * 	and finally calls this animateIn() method.
		 *  Your story is now visible.
		 * 	Use this method to begin animating your story.
		 * 	The configXML property can now be accessed.
		 */
		public override function animateIn():void {
			Log.USE_LOG && Log.logmsg("Animate in.");
			// Show intro animations
			
			// Set framework menu color to WHITE or BLACK
			color = WHITE;
			
			/*----------------------------------
			
			// The following are MANDATORY methods for proper communication with the
			// framework. These methods do not have to be called within the animateIn()
			// method, but they should be called at some point in your story.
			
			storyReady();
			// Indicates to the framework that your story is ready. Usually applied when
			// your story's Begin/Enter/Start button is clicked or when a bottom bar 
			// navigation link is clicked (except "Start Over") 
			
			showFooterLinks();
			// Displays the bottom bar navigation links. Call this as soon as your story
			// can handle bottomNavClick() calls.
			
			track(page:String);
			// Analytics tracking for all pages, sections, subsections, and assets in
			// your story. Pass this method any string that you want to track, but 
			// ignore your story name. eg. If your story is Waterlife and the page you
			// want to track is called Poison just send "poison". The framework will 
			// automatically prepend your story name so the link will be tracked as
			// "waterlife_poision". If you want to track a sub-page of Poison called
			// Bleach, you should send "posion_bleach".
			
			//----------------------------------*/
			
			// Add bottom navigation bar only for out-of-framework testing
			
			if (OUT_OF_FRAMEWORK) {
				BotNav.bar_height = navBarHeight;
				botNav = new BotNav(this, configXML, stageW, stageH, language, useTouch);
				addChild(botNav);
				onResize(null);
			} else {
				storyReady();
				showFooterLinks();
				track("video");
			}
		}
		
		public override function changeLanguage(newLang:String):void {
			// Only English, French, and Khmer in this app.
			if (newLang != language) {
				language = newLang;
				mediaPlayer.setLanguage(newLang);
			}
		}
		
		/**
		 * 	The bottomNavClick() method is called by the framework when any of the
		 *  story-specific left-side footer links are clicked. 
		 *  e.g. START OVER, ABOUT THE STORY, RELATED NFB FILMS
		 * 	Use this method to handle footer link clicks sent in from the framework.
		 *	Your story should be able to accept bottomNavClick() calls as soon as
		 * 	animateIn() is called.
		 *
		 *	@param link		The text name of the footer link as defined in config.xml
		 */
		public override function bottomNavClick(link:String):void {
			// Compare link value to configXML and get the corresponding link number
			var bottomLinkNum:Number = getBottomLinkNum(link);
			
			Log.USE_LOG && Log.logmsg("BOTNAV: " + link + " - NUM: " + bottomLinkNum);
			
			switch (bottomLinkNum) {
				case 0:
					// Navigation (touch only).
					mediaPlayer.showNavigation();
					break;
				
				case 1:
					// Start Over
					mediaPlayer.startOver();
					break;
				
				case 2:
					// Show About
					mediaPlayer.showAbout();
					break;
				
				case 3:
					// Show Credits
					mediaPlayer.showCredits();
					break;
				
				case 4:
					// Related films
					showRelated();
					break;
				
				case 5:
					// Change language
					if (language == Strings.LANG_EN) {
						changeLanguage(Strings.LANG_FR);
					} else if (language == Strings.LANG_FR) {
						changeLanguage(Strings.LANG_KH);
					} else {
						changeLanguage(Strings.LANG_EN);
					}
					break;
				
				case 6:
					//Fullscreen
					if (stage.displayState == StageDisplayState.FULL_SCREEN) {
						stage.displayState = (StageDisplayState.NORMAL);
						botNav ? botNav.setButtonActive(bottomLinkNum, false) : null;
						resize(stage.stageWidth, stage.stageHeight);
					} else {
						stage.displayState = (StageDisplayState.FULL_SCREEN);
						botNav ? botNav.setButtonActive(bottomLinkNum, true) : null;
						resize(stage.fullScreenWidth, stage.fullScreenHeight);
					}
					break;
				
				case 7:
					//Mute
					if (isMuted) {
						mediaPlayer.unmute();
						botNav ? botNav.setButtonActive(bottomLinkNum, false) : null;
					} else {
						mediaPlayer.mute();
						botNav ? botNav.setButtonActive(bottomLinkNum, true) : null;
					}
					isMuted = !isMuted;
					break;
			}
			
			/*----------------------------------
			
			// DEEP LINKING
			// Deep linking is based on SWFAddress and is available via the framework
			// if you wish to use it, but it is not a required feature.
			// Two methods are available to use deep linking:
			
			setDeepLink("section_subsection");
			// Calling the setDeepLink() method changes the deep link to
			// http://interactive.nfb.ca/#/storyname_section_subsection
			// Note that your story's name will be automatically prepended to the deep
			// link string.
			
			gotDeepLink();
			// See details about this overridden method in code below.
			
			----------------------------------*/
			
			// Call storyReady() to close the menu for all links except "Start Over".
			if (bottomLinkNum != 1) {
				storyReady();
			}
		}
		
		/**
		 * 	Show the RELATED NFB FILMS page from the footer links.
		 */
		protected function showRelated():void {
			if (OUT_OF_FRAMEWORK) {
				mediaPlayer.showRelated();
			} else {
				pause();
				
				linkTo(baseURL + "relatedfilms");
				
				// Stats tracking will be recorded as "invisibleworld_related"
				track("related");
			}
		}
		
		public override function pause():void {
			mediaPlayer.pause();
		}
		
		public override function resume():void {
			mediaPlayer.resume();
		}
		
		/**
		 * 	The gotDeepLink() method is called by the framework when there are 
		 *  changes to the deep link URL. This works the same as SWFAddress which you
		 *  can use as an alternative.
		 *	Remember to parse the string for the project's identifier.
		 *  e.g. Framework passes "/testtube/about" - strip the "/testtube/" part.
		 * 	Use this method to handle deep link changes sent in from the framework.
		 *
		 *	@param str	The full deep link URL path after the # 
		 *				e.g. http://interactive.nfb.ca/#/dogs/about will return as
		 *				/dogs/about	
		 */	
		public override function gotDeepLink(str:String):void  {
			// Parse second-level deeplink for story-specific use.
			//var deepLinks:Array = str.split("/");
			//var link:String = deepLinks[2].toLowerCase();
			
			// Second-level deep link string
			Log.USE_LOG && Log.logmsg("Clicked " + str + " -- ");
			switch (str) {
				case "facebook":
					// Jump to share page
					setDeepLink(baseURL + "share/facebook");
					linkTo(baseURL + "share/facebook");
					break;
				case "twitter":
					// Jump to share page
					setDeepLink(baseURL + "share/twitter");
					linkTo(baseURL + "share/twitter");
					break;
				case "stumbleupon":
					// Jump to share page
					setDeepLink(baseURL + "share/stumbleupon");
					linkTo(baseURL + "share/stumbleupon");
					break;
				case "digg":
					// Jump to share page
					setDeepLink(baseURL + "share/digg");
					linkTo(baseURL + "share/digg");
					break;
				case "delicious":
					// Jump to share page
					setDeepLink(baseURL + "share/delicious");
					linkTo(baseURL + "share/delicious");
					break;
				default:
					break;
			}
		}
		
		/**
		 *	Takes the string name of the footer link 
		 *	e.g. START OVER | ABOUT THE PROJECT | RELATED NFB FILMS	
		 *	and returns the index of the footer link starting at 1.
		 *	e.g. 1 = START OVER
		 *		 2 = ABOUT THE PROJECT
		 *		 3 = RELATED NFB FILMS
		 *
		 *	@param _str		The string name of the footer link
		 *
		 *	@return 		The index (starting at 1) of the bottom footer link
		 */
		protected function getBottomLinkNum(_str:String):Number {
			var totalLinks:int = configXML.links.link.length();
			var num:int = 0;
			for (var i:int = 1; i <= totalLinks; i++) {
				var str:String = String(configXML.links.link[i-1]);
				if(str == _str)
					num = i;
			}
			return num;
		}
		
		public override function resize(containerWidth:Number, containerHeight:Number):void {
			stageW = containerWidth;
			stageH = containerHeight;
			
			// Resize UI elements
			if (botNav) {
				botNav.resizeBotNav(containerWidth, containerHeight - botNav.height);
				stageH -= botNav.height;
			}
			
			if (mediaPlayer) {
				mediaPlayer.resize(stageW, stageH);
			}
		}
		
		/**
		 * 	The onResize() method is used only for out-of-framework testing.
		 * 	Please implement all resizing using the overridden resize() method.
		 */
		protected function onResize(e:Event = null):void {
			resize(stage.stageWidth, stage.stageHeight);
		}
		
		protected function onChangeLanguage(e:MainPlayerEvent):void {
			changeLanguage(e.data as String);
		}
		
		protected function onLoadFailed(e:MainPlayerEvent):void {
			Log.USE_LOG && Log.logmsg("Ok, load failed. Now what? " + e.data.url);
		}
		
		protected function onDownloadApp(e:MainPlayerEvent):void {
			Log.USE_LOG && Log.logmsg("Download the app for your viewing convenience.");
			linkTo(baseURL + "download");
		}
		
		private function onReadyToReceiveMedia(e:MainPlayerEvent):void {
			Log.USE_LOG && Log.logmsg("Ready to receive media");
		}
		
		private function onTrackAnalytics(e:MainPlayerEvent):void {
			track(e.data as String);
		}
		/**
		 * 	The cleanUp() method is called when the user leaves the current story.
		 * 	Any resources that are not automatically garbage-collected should be
		 *  removed. e.g. event listeners, video streams, etc.
		 *	Note: Your story should not rely on the REMOVED_FROM_STAGE event for 
		 *	final clean up.
		 */
		public override function cleanUp():void {
			// Remove listeners, clear netstreams, dispose of bitmapData etc...
			if (OUT_OF_FRAMEWORK) stage.removeEventListener(Event.RESIZE, onResize);
			
			// Stop framerate profiler
			PerformanceProfiler.fpsStop();
		}
	}
}