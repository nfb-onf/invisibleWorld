package ca.nfb.interactive.events {
	import flash.events.Event;
	
	public class NavigationEvent extends Event {
		public static const CHANGE_SECTION:String = "CHANGE_SECTION"
		public static const CHANGE_MAIN_MODE:String = "CHANGE_MAIN_MODE"
		public static const NEXT_PROJECT:String = "NEXT_PROJECT"
		public static const PREV_PROJECT:String = "PREV_PROJECT"
		public static const LOAD_PROJECT:String = "LOAD_PROJECT"
		public static const HIDE_MENU:String = "HIDE_MENU"
		public static const SET_MENU:String = "SET_MENU"
		public static const CHANGE_BROWSE:String = "SET_MENU"
		public static const SET_BROWSE:String = "SET_BROWSE"
		
		public var link:String
		public function NavigationEvent(type:String,link:String="", bubbles:Boolean=false, cancelable:Boolean=false) {
			this.link  = link
			
			super(type, bubbles,cancelable)
		}
		public override function clone():Event {
			return new NavigationEvent(type,link, bubbles, cancelable);
		}
	}
}