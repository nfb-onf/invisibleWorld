package ca.nfb.interactive.content {
	import flash.display.MovieClip;
	import flash.display.Sprite;
	
	import ca.nfb.interactive.utils.TweenUtil;

	public class SliderContainer extends Sprite {
		private static const MOUSE_OVER_OFFSET:Number = 8;
		
		private var isRight:Boolean; // Is the mask on the right side.
		private var isMouseOver:Boolean; // Is mouse over this mask.
		
		private var stageW:int; // Parent stage width
		private var stageH:int; // Parent stage height
		private var openOff:int; // Offset of an oblong mask. Used to move entire mask off stage.
		
		public var vidMask:MovieClip; // Used as a mask for vid holders.
		public var vidFade:MovieClip; // Used as a grip and faded black screen for mask.
		public var instruction:MovieClip; // Instructions that fade on tutorial.
		
		public function SliderContainer(right:Boolean, wid:int, hei:int, openOffset:int = 200, isMobile:Boolean = false) {
			isRight = right;
			stageW = wid;
			stageH = hei;
			openOff = openOffset;
			
			// Add instructions to the grips.
			instruction = isMobile ? new TouchDrag() : new ClickDrag();
			instruction.visible = false;
			instruction.alpha = 0;
			instruction.y = (hei - instruction.height) * .5;
			instruction.x = right ? instruction.width : -instruction.width;
			instruction.cacheAsBitmap = true;
			
			// Create the masks.
			vidMask = right ? new vidMaskRight : new vidMaskLeft();
			vidMask.mouseEnabled = false;
			vidMask.cacheAsBitmap = true;
			
			// Create faded foreground to show the buttons.
			vidFade = right ? new SliderButtonRight() : new SliderButtonLeft();
			vidFade.mouseEnabled = false;
			vidFade.cacheAsBitmap = true;
			
			addChild(vidMask);
			addChild(vidFade);
			addChild(instruction);
			
			mouseEnabled = true;
			
			resetPosition();
		}
		
		public function get mouseOver():Boolean {
			return isMouseOver;
		}
		
		public function resetPosition():void {
			x = isRight ? stageW + openOff : -openOff;
		}
		
		public function showGrip():void {
			vidFade.visible = true;
			vidFade.alpha = 1;
		}
		
		public function hideGrip():void {
			vidFade.visible = false;
			vidFade.alpha = 0;
		}
		
		public function showInst():void {
			instruction.visible = true;
		}
		public function hideInst():void {
			instruction.visible = false;
		}
		
		public function mouseOn():void {
			isMouseOver = true;
			TweenUtil.moveEase(vidFade, isRight ? MOUSE_OVER_OFFSET : -MOUSE_OVER_OFFSET);
			TweenUtil.moveEase(vidMask, isRight ? MOUSE_OVER_OFFSET : -MOUSE_OVER_OFFSET);
		}
		
		public function mouseOff():void {
			isMouseOver = false;
			TweenUtil.moveEase(vidFade, 0);
			TweenUtil.moveEase(vidMask, 0);
		}
	}
}