
/**
 * BaseNFB Class for NFB/Interactive stories
 * @version: 1.3                                                                                                             
 * @date: April 4, 2012
 */

package ca.nfb.interactive.content {
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.net.URLRequest;
	import flash.net.navigateToURL;
	
	import ca.nfb.interactive.events.NavigationEvent;
	
	public class BaseNFB extends Sprite {
		public static const READY:String = "READY";
		public static const STORY_STARTED:String = "PROJECT_STARTED";
		public static const ENGLISH:String = "ENGLISH";
		public static const FRENCH:String = "FRENCH";
		public static const ENTER_FULL_SCREEN:String = "ENTER_FULL_SCREEN";
		public static const EXIT_FULL_SCREEN:String = "EXIT_FULL_SCREEN";
		public static const COLOUR_CHANGED:String = "COLOUR_CHANGED";
		public static const	BLACK:String = "BLACK";
		public static const	WHITE:String = "WHITE";
		public static const	SHOW_FOOTER_LINKS:String = "SHOW_FOOTER_LINKS";
		public static const	HIDE_FOOTER_LINKS:String = "HIDE_FOOTER_LINKS";
		public static const DEEP_LINK:String = "SET_DEEPLINK";
		
		protected var _deepLinked:Boolean = false;
		
		private var _baseURl:String = "";
		
		private var _configXml:XML;
		
		//quality is a value 0 -> 2 ::  2 is high, 0 is low.  also stored as constants. Eg: PerformanceProfiler.QUALITY_MED
		private var _quality:int = 2;
		private var intIsPaused:Boolean = false;
		private var currentColor:String = "BLACK";
		
		private var _origin:String = "";
		private var _deepLink:String = "";
		private var _lang:String = "";
		
		public function BaseNFB() {
			super();
		}
		
		
		public function resize(containerWidth:Number, containerHeight:Number):void{
			throw new Error("RESIZE MUST BE OVERRIDDEN")
		}
		
		public function animateIn():void{
			throw new Error("ANIMATEIN MUST BE OVERRIDDEN")
		}
		
		public function start():void{
			throw new Error("START MUST BE OVERRIDDEN")
			
		}
		public function pause():void{
			throw new Error("PAUSE MUST BE OVERRIDDEN")
			
		}
		public function resume():void{
			throw new Error("RESUME MUST BE OVERRIDDEN")
			
		}		
		public function bottomNavClick(link:String):void{
			throw new Error("LEFTNAVCLICK MUST BE OVERRIDDEN")
		}
		
		
		public function cleanUp():void{
			/**
			 * this function should remove all listeners and clean up anything that might not get 
			 * garbage collected automatically
			 * 
			 * 
			 * This is arguably the most important function in this class.  Please Please Please double check to make sure
			 * that everything that can be garbage collected is being cleaned up and disposed of properly. 
			 * */
			
			throw new Error("CLEANUP MUST BE OVERRIDDEN")
		}
		public function get isPaused():Boolean{
			return intIsPaused
		}
		public function set isPaused(val:Boolean):void{
			intIsPaused = val
		}
		
		public function set deepLinked(val:Boolean):void{
			_deepLinked = val
		}
		public function get deepLinked():Boolean{
			return _deepLinked
		}
		public function set baseURL(val:String):void{
			_baseURl = val
		}
		public function get baseURL():String{
			return _baseURl
		}
		public function set originServer(val:String):void{
			_origin = val
		}
		public function get originServer():String{
			return _origin
		}
		
		//DEEPLINK Update
		public function set deeplink(val:String):void {
			_deepLink = val;
		}
		
		public function get deeplink():String {
			return _deepLink;
		}
		
		public function get lang():String {
			return _lang;
		}
		
		public function set quality(val:int):void{
			_quality = val
		}
		
		public function set configXML(val:XML):void{
			_configXml = val;
		}
		public function get configXML():XML {
			return _configXml;
		}
		
		public function get quality():int{
			return _quality;
		}
		
		public function enterFullScreen():void{
			dispatchEvent(new Event(ENTER_FULL_SCREEN));
		}
		public function exitFullScreen():void{
			dispatchEvent(new Event(EXIT_FULL_SCREEN));
		}
		public function updateFooterMediaLabel(audioName:String):void{
			dispatchEvent(new MediaEvent(MediaEvent.UPDATE_FOOTER_LABEL, audioName))
		}
		public function track(trackStr:String):void{
			/**
			 * pass this function a string that you want to track.  ignore your project name.
			 * eg. if you're probject is waterlife and the page you want to track is poison just sent "poison"
			 * the actual link that will be tracked will be "/waterlife/poision" but the framework will handle that for you.
			 * if its a sub page of poison you should send "posion/bleach"
			 * */
			dispatchEvent(new TrackingEvent(TrackingEvent.TRACK,trackStr))
			
		}
		public function set color(color:String):void{
			/** this controls the color of the framework overlays.  If the project is very dark it doesnt 
			 * make sense to overlay black text on it. If your project is white the text should be dark.
			 * please use the constants included to set the color  IE BaseNFB.BLACK and BaseNFB.WHITE
			 * */
			
			currentColor = color
			
			dispatchEvent(new Event(COLOUR_CHANGED))
			
		}
		public function get color():String{
			return currentColor			
		}
		
		
		public function storyReady():void{
			/**
			 * should be called when the project is fully loaded so that the bottom nav, etc...,  can be activated
			 * 
			 * */
			dispatchEvent(new Event(STORY_STARTED))
		}
		
		public function readyToAnimate():void{
			/**this should be called when the backrgound image is loaded and
			 * on added to the display list but before any text or video starts.
			 * For example, If its video that will be displayed the video should start to load and be paused on the first screen.
			 * When animateIn is called it should start playing.
			 **/			
			dispatchEvent(new Event(READY))
		}
		
		public function changeLanguage(Lang:String):void
		{
			dispatchEvent(new Event(Lang));
		}
		
		public function showFooterLinks():void
		{
			dispatchEvent(new Event(BaseNFB.SHOW_FOOTER_LINKS));
		}
		
		public function hideFooterLinks():void
		{
			dispatchEvent(new Event(BaseNFB.HIDE_FOOTER_LINKS));
		}		
		
		public function linkTo(url:String, target:String="_self"):void
		{		
			var request:URLRequest = new URLRequest(url);
			track("link/" + url);
			try {
				navigateToURL(request, target);
			} catch (e:Error) {
				trace("Error occurred!");
			}
		}
		
		
		// Deep Links
		public function setDeepLink(str:String):void{	
			dispatchEvent(new NavigationEvent(DEEP_LINK,deeplink+"/"+str));
			
		}
		public function gotDeepLink(str:String):void{
			trace("BaseNFB Class::gotDeepLink::" + str);
			/** 
			 * Can either use this function for deeplinks or you can continue to use SWFAddress.as.
			 * Remember to parse the string for the project's identifier. IE  "/mainstreet/about" the project will have to strip out the mainstreet part. 
			 * 
			 * */			
		}
		
		
		// Contact Form
		public function submitContactForm(fromName:String, fromEmail:String, msg:String):void {
			dispatchEvent(new ContactFormEvent(ContactFormEvent.SUBMIT_FORM, fromName, fromEmail, msg));
		}
		
		public function receiveContactFormResponse(msg:String):void {
			/*
			switch (msg) {
			case ("message=" + ContactFormEvent.SUCCESS_MSG_SENT):
			trace("Success");
			break;
			case ("message=" + ContactFormEvent.ERROR_MSG_SENT):
			trace("Error");
			break;
			case ("message=" + ContactFormEvent.ERROR_REQUIRED_PARAM_MISSING):
			trace("Missing parameter");
			break;
			case ("message=" + ContactFormEvent.ERROR_BAD_KEY):
			trace("Bad key");
			break;
			default:
			trace("Unknown form script response::" + msg);
			break;
			}
			*/
		}
		
	}
}