package {
	import ca.nfb.interactive.data.Strings;
	import ca.nfb.interactive.display.VideoPlayerVideoTexture;
	
	[SWF(backgroundColor="0x000000")]
	public class InvisibleWorldIOS extends InvisibleWorldBase {
		
		public function InvisibleWorldIOS() {
			super();
			
			playerUrl = "MainPlayer.swf";
			Strings.load = Strings.VIDEO_MAIN;
			
			if (deviceType == "tablet") {
				configUrl = language + "/config_iOS_tablet.xml";
				timelineHeight = 50;
				navBarHeight = 50;
			} else if (deviceType == "mobile") {
				configUrl = language + "/config_iOS_mobile.xml";
				timelineHeight = 60;
				navBarHeight = 60;
			} else {
				configUrl = language + "/config_iOS_tablet.xml";
				timelineHeight = 50;
				navBarHeight = 50;
			}
			
			// BitmapData won't work on iOS. Force video texture player.
			videoPlayer = new VideoPlayerVideoTexture(stage, mainW, mainH, deviceName, deviceVersion);
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
			
			// Call storyReady() to close the menu for all links except "Start Over".
			if (bottomLinkNum != 1) {
				storyReady();
			}
		}
	}
}