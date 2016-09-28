package ca.nfb.interactive.content {
	import flash.events.Event;
	
	public class ContactFormEvent extends Event {
		public static const SUBMIT_FORM:String = "SUBMIT_FORM";
		public static const SUCCESS_MSG_SENT:String = "SUCCESS_MSG_SENT";
		public static const ERROR_MSG_SENT:String = "ERROR_MSG_SENT";
		public static const ERROR_REQUIRED_PARAM_MISSING:String = "ERROR_REQUIRED_PARAM_MISSING";
		public static const ERROR_BAD_KEY:String = "ERROR_BAD_KEY";
				
		public var fromName:String;
		public var fromEmail:String;
		public var msg:String;
		
		public function ContactFormEvent(type:String, fromName:String, fromEmail:String, msg:String, bubbles:Boolean=false, cancelable:Boolean=false)
		{			
			this.fromName = fromName;
			this.fromEmail = fromEmail;
			this.msg = msg;
			
			super(type, bubbles, cancelable);
		}
		
		public override function toString():String
		{
			return '[LinkEvent type = "' + type + '" fromName = "' + fromName + '" fromEmail = "' + fromEmail + '" msg = "' + msg + '"]';
		}
		
		public override function clone():Event
		{
			return new ContactFormEvent(type, fromName, fromEmail, msg, bubbles, cancelable);
		}
		
	}
}