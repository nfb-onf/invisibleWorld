package ca.nfb.interactive.utils {
	import com.gskinner.motion.GTween;
	import com.gskinner.motion.GTweenTimeline;
	import com.gskinner.motion.GTweener;
	import com.gskinner.motion.easing.Linear;
	import com.gskinner.motion.easing.Sine;
	
	import flash.display.Bitmap;
	import flash.display.Sprite;

	public class TweenUtil {
		
		public static function fade(obj:Object, time:Number = 1, from:Number = 0, to:Number = 1):GTween {
			GTweener.removeTweens(obj);
			obj.alpha = from;
			var tween:GTween = GTweener.to(obj, time, {alpha: to}, {ease: Linear.easeNone});
			tween.onComplete = handleTweenComplete;
			return tween;
		}
		
		public static function fadeOutBmp(obj:Bitmap, time:Number = 1):GTween {
			GTweener.removeTweens(obj);
			var tween:GTween = GTweener.to(obj, time, {alpha: 0}, {ease: Linear.easeNone});
			tween.onComplete = handleTweenVanishComplete;
			return tween;
		}
		
		public static function fadeInBmp(obj:Bitmap, time:Number = 1, fade:Number = 1):GTween {
			obj.visible = true;
			GTweener.removeTweens(obj);
			var tween:GTween = GTweener.to(obj, time, {alpha: fade}, {ease: Linear.easeNone});
			tween.onComplete = handleTweenComplete;
			return tween;
		}
		
		public static function fadeOut(obj:Sprite, time:Number = 1):GTween {
			GTweener.removeTweens(obj);
			var tween:GTween = GTweener.to(obj, time, {alpha: 0}, {ease: Linear.easeNone});
			tween.onComplete = handleTweenComplete;
			return tween;
		}
		
		public static function fadeIn(obj:Sprite, time:Number = 1, fade:Number = 1):GTween {
			obj.visible = true;
			GTweener.removeTweens(obj);
			var tween:GTween = GTweener.to(obj, time, {alpha: fade}, {ease: Linear.easeNone});
			tween.onComplete = handleTweenComplete;
			return tween;
		}
		
		public static function moveEase(obj:Sprite, destX:Number, time:Number = .5):GTween {
			GTweener.removeTweens(obj);
			var tween:GTween = new GTween(obj, time, {x: destX}, {ease: Sine.easeOut});
			tween.onComplete = handleTweenComplete;
			GTweener.add(tween);
			return tween;
		}
		
		public static function moveBounce(obj:Sprite, destX:Number, time:Number = .5):GTween {
			var timeline:GTweenTimeline;
			GTweener.removeTweens(obj);
			timeline = new GTweenTimeline(obj, time);
			var bounceX:Number = destX - ((destX - obj.x) / 30);
			timeline.onComplete = handleTweenComplete;
			timeline.addTween(0, new GTween(obj, time * 0.6, {x: destX}, {ease: Sine.easeOut}));
			timeline.addTween(time * 0.6, new GTween(obj, time * 0.2, {x: bounceX}, {ease: Sine.easeIn}));
			timeline.addTween(time * 0.8, new GTween(obj, time * 0.2, {x: destX}, {ease: Sine.easeOut}));
			GTweener.add(timeline);
			return timeline;
		}
		
		public static function removeTweensFromObject(o:Object):void {
			if (GTweener.getTweens(o).length > 0) {
				GTweener.removeTweens(o);
			}
		}
		
		public static function handleTweenComplete(t:GTween):void {
			GTweener.removeTweens(t.target);
		}
		
		public static function handleTweenVanishComplete(t:GTween):void {
			t.target.visible = false;
			GTweener.removeTweens(t.target);
		}
		
		public static function handleTweenRemoval(t:GTween):void {
			GTweener.remove(t);
			if (t.target && t.target.parent) {
				t.target.parent.removeChild(t.target);
			}
		}
	}
}