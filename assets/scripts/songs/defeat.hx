import funkin.play.PlayState;
import funkin.play.song.Song;
import funkin.Highscore;
import flixel.text.FlxText;
import flixel.text.FlxTextBorderStyle;
import flixel.FlxG;
import funkin.Paths;
import funkin.play.PauseSubState;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.text.FlxTextAlign;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;

class DefeatSongScript extends Song
{
  public function new()
  {
    super('defeat');
  }

  var maxMisses:Int = 5;

  var ps:PlayState;
  var missText:FlxText;
  var alreadyKilled:Bool = false;

  function getMaxMissesForDifficulty():Int
  {
    var diff:String = '';
    try
    {
      diff = Std.string(PlayState.instance.currentDifficulty).toLowerCase();
    }
    catch (e:Dynamic)
    {
    }

    switch (diff)
    {
      case 'easy':
        return 5;
      case 'normal':
        return 4;
      case 'hard':
        return 3;
      case 'erect':
        return 2;
      case 'nightmare':
        return 0;
      default:
        return 5;
    }
  }

  override function onCreate(e)
  {
    super.onCreate(e);
    ps = PlayState.instance;
    alreadyKilled = false;

    maxMisses = getMaxMissesForDifficulty();

    PauseSubState.musicSuffix = '-defeat';

    try
    {
      if (postUpdateFn != null) FlxG.signals.postUpdate.remove(postUpdateFn);
      postUpdateFn = function() { try { pauseHook(); } catch (err:Dynamic) {} };
      FlxG.signals.postUpdate.add(postUpdateFn);
    }
    catch (err:Dynamic) { }

    touchMenu = TOUCH_ON_DESKTOP;
    try { if (FlxG.onMobile) touchMenu = true; }
    catch (err:Dynamic) {}

    if (ps.scoreText != null) ps.scoreText.visible = false;

    if (ps.healthBar != null) ps.healthBar.visible = false;
    if (ps.healthBarBG != null) ps.healthBarBG.visible = false;
    if (ps.iconP1 != null) ps.iconP1.visible = false;
    if (ps.iconP2 != null) ps.iconP2.visible = false;

    missText = new FlxText(ps.healthBarBG.x, ps.healthBarBG.y + 13, ps.healthBarBG.width, "Score: 0 | Misses: 0/" + maxMisses, 22);
    missText.setFormat(Paths.font("vcr.ttf"), 22, 0xFFFF0000, 'center', FlxTextBorderStyle.OUTLINE, 0xFF000000);
    missText.borderColor = 0xFF000000;
    missText.borderSize = 2;
    missText.scrollFactor.set();
    missText.cameras = [ps.camHUD];
    missText.zIndex = 99999;
    ps.add(missText);

    centerPlayerStrumline();
    hideOpponentStrumline();
  }

  static inline var PAUSE_PORTRAIT:String = 'menu/pause/black';
  static inline var PAUSE_GLOW:String = 'menu/pause/backGlow';
  static inline var PAUSE_GLOW_COLOR:Int = 0xFFFF0000;
  static inline var PAUSE_SCROLL_SOUND:String = 'hover';
  static inline var PAUSE_SCROLL_VOLUME:Float = 0.5;
  static inline var TOUCH_ON_DESKTOP:Bool = false;
  static inline var PAUSE_TITLE:String = 'Defeat';
  static inline var PAUSE_CREDITS:String = 'Composer: Rareblin\nCharter: Orbyy';

  var pauseDecorated = null;
  var pauseTries:Int = 0;
  var pauseSub = null;
  var pauseBgSprite = null;
  var pauseMenuGroup = null;
  var menuTexts:Array<FlxText> = [];
  var menuSig:String = '';
  var menuSel:Int = 0;
  var hideErrLogged:Bool = false;
  var menuNotFoundLogged:Bool = false;
  var menuRunLogged:Bool = false;
  var menuDbg:Int = 0;
  var menuPrevSel:Int = -1;
  var touchMenu:Bool = false;
  var touchDelay:Float = 0;
  var touchGroupMoved:Bool = false;
  var practiceText:FlxText = null;
  var pauseSession:Int = 0;

  override function onPause(event)
  {
    super.onPause(event);

    pauseSession++;
    pauseDecorated = null;
    pauseSub = null;
    practiceText = null;
    pauseBgSprite = null;
    pauseMenuGroup = null;
    menuTexts = [];
    menuSig = '';
    menuPrevSel = -1;
    touchDelay = 0.3;
    touchGroupMoved = false;
    menuDbg = 0;
    pauseTries = 0;
    pauseActive = true;
  }

  override function onResume(event)
  {
    super.onResume(event);
    pauseActive = false;
    pauseSession++;
    pauseDecorated = null;
    pauseSub = null;
    practiceText = null;
    pauseBgSprite = null;
    pauseMenuGroup = null;
    menuTexts = [];
    menuSig = '';
    menuPrevSel = -1;
    touchDelay = 0.3;
    touchGroupMoved = false;
  }

  var pauseActive:Bool = false;
  var postUpdateFn = null;

  function pauseHook():Void
  {
    if (!pauseActive) return;

    var p = PlayState.instance;
    var sub = (p != null) ? p.subState : null;

    if (sub == null || !Std.isOfType(sub, PauseSubState) || sub.members.length == 0) return;

    if (pauseDecorated != sub)
    {
      pauseDecorated = sub;

      try { FlxG.sound.play(Paths.sound('panelAppear'), 0.5); }
      catch (e:Dynamic) { }

      try { decoratePauseSubState(sub); }
      catch (e:Dynamic) { }
    }
    else
    {
      try { updatePauseExtras(); }
      catch (e:Dynamic) {}
    }
  }

  function prettyDifficulty():String
  {
    var d:String = '';
    try { d = Std.string(PlayState.instance.currentDifficulty); }
    catch (e:Dynamic) { return 'Unknown'; }

    var out:String = '';
    var words = d.split('-').join(' ').split(' ');
    for (w in words)
    {
      if (w.length == 0) continue;
      if (out.length > 0) out += ' ';
      out += w.charAt(0).toUpperCase() + w.substr(1).toLowerCase();
    }
    return (out.length > 0) ? out : 'Unknown';
  }

  function hideVSliceMetadata(sub):Void
  {
    try
    {
      var md = Reflect.field(sub, 'metadata');
      if (md != null) md.visible = false;
    }
    catch (e:Dynamic) {}

    for (m in sub.members)
    {
      if (m == null) continue;
      try
      {
        if (m == pauseTitle || m == pauseCredits || m == practiceText) continue;
        if (menuTexts.indexOf(m) != -1) continue;

        if (Std.isOfType(m, FlxText))
        {
          m.visible = false;
        }
        else
        {
          var kids = m.members;
          if (kids != null && kids.length > 0 && Std.isOfType(kids[0], FlxText))
          {
            m.visible = false;
            for (k in kids) { if (k != null) k.visible = false; }
          }
        }
      }
      catch (e:Dynamic)
      {
        if (!hideErrLogged) { hideErrLogged = true; }
      }
    }
  }

  var pauseTitle:FlxText = null;
  var pauseCredits:FlxText = null;

  function decoratePauseSubState(sub):Void
  {
    pauseSub = sub;
    hideVSliceMetadata(sub);
    try { updateCustomMenu(sub); } catch (e:Dynamic) {}

    var bgIndex:Int = -1;
    try
    {
      var bg = Reflect.field(sub, 'background');
      if (bg != null) bgIndex = sub.members.indexOf(bg);
    }
    catch (e:Dynamic) { bgIndex = -1; }

    if (bgIndex < 0)
    {
      try
      {
        for (i in 0...sub.members.length)
        {
          var m = sub.members[i];
          if (m != null && Std.isOfType(m, FlxSprite) && m.width >= FlxG.width && m.height >= FlxG.height)
          {
            bgIndex = i;
            break;
          }
        }
      }
      catch (e:Dynamic) { bgIndex = -1; }
    }

    if (bgIndex >= 0)
    {
      try
      {
        pauseBgSprite = sub.members[bgIndex];
        FlxTween.globalManager.cancelTweensOf(pauseBgSprite);
      }
      catch (e:Dynamic) { pauseBgSprite = null; }
    }

    var glow:FlxSprite = new FlxSprite(500, -12.65).loadGraphic(Paths.image(PAUSE_GLOW, 'shared'));
    glow.color = PAUSE_GLOW_COLOR;
    glow.scrollFactor.set(0, 0);

    var portrait:FlxSprite = new FlxSprite(0, 0).loadGraphic(Paths.image(PAUSE_PORTRAIT, 'shared'));
    portrait.scrollFactor.set(0, 0);
    var endX:Float = 304.65 + (1215 - portrait.frameWidth) * 0.5;
    portrait.y = -125 + (1097 - portrait.frameHeight) * 0.5;
    portrait.x = FlxG.width + (1215 - portrait.frameWidth) * 0.5;

    if (bgIndex >= 0)
    {
      sub.insert(bgIndex + 1, glow);
      sub.insert(bgIndex + 2, portrait);
    }
    else
    {
      sub.add(glow);
      sub.add(portrait);
    }
    FlxTween.tween(portrait, {x: endX}, 0.3, {ease: FlxEase.circOut});

    var pad:Int = 15;

    var title:FlxText = new FlxText(0, pad, FlxG.width - pad, PAUSE_TITLE);
    title.setFormat(Paths.font('liberbold.ttf'), 24, FlxColor.WHITE, FlxTextAlign.RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    title.scrollFactor.set(0, 0);
    sub.add(title);

    var credits:FlxText = new FlxText(0, 30 + pad, FlxG.width - pad, PAUSE_CREDITS + '\nDifficulty: ' + prettyDifficulty());
    credits.setFormat(Paths.font('liber.ttf'), 24, FlxColor.WHITE, FlxTextAlign.RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    credits.scrollFactor.set(0, 0);
    sub.add(credits);

    practiceText = new FlxText(0, credits.y + credits.height, FlxG.width - pad, 'PRACTICE MODE');
    practiceText.setFormat(Paths.font('liberbold.ttf'), 24, FlxColor.WHITE, FlxTextAlign.RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    practiceText.scrollFactor.set(0, 0);
    practiceText.visible = PlayState.instance.isPracticeMode;
    sub.add(practiceText);

    pauseTitle = title;
    pauseCredits = credits;
  }


  function updateCustomMenu(sub):Void
  {
    if (!menuRunLogged) { menuRunLogged = true; }
    var e:Float = FlxG.elapsed;
    if (e != e || e <= 0 || e > 0.1) e = 0.016;
    var k:Float = Math.min(e * 15.6, 1);

    if (pauseBgSprite != null) pauseBgSprite.alpha = pauseBgSprite.alpha + (0.8 - pauseBgSprite.alpha) * k;

    if (pauseMenuGroup == null)
    {
      var fallback = null;
      var fallbackArea:Float = -1;

      for (i in 0...sub.members.length)
      {
        var m = sub.members[i];
        if (m == null) continue;

        try
        {
          var kids = m.members;
          if (kids == null || kids.length == 0) continue;
          if (Std.isOfType(kids[0], FlxText)) continue;

          var area:Float = m.width * m.height;
          if (area > fallbackArea) { fallbackArea = area; fallback = m; }

          var t = Std.string(kids[0].text);
          if (t != null && t != 'null')
          {
            pauseMenuGroup = m;
            break;
          }
        }
        catch (err:Dynamic)
        {
        }
      }

      if (pauseMenuGroup == null && fallback != null)
      {
        pauseMenuGroup = fallback;
      }

      if (pauseMenuGroup == null)
      {
        if (!menuNotFoundLogged) { menuNotFoundLogged = true; }
        return;
      }
    }

    pauseMenuGroup.visible = false;

    var kids = pauseMenuGroup.members;
    var labels:Array<String> = [];
    var sel:Int = 0;
    var best:Float = -1;
    for (i in 0...kids.length)
    {
      var kid = kids[i];
      var lbl:String = '';
      try { lbl = Std.string(kid.text); } catch (er:Dynamic) { lbl = 'Option ' + (i + 1); }
      labels.push(lbl);
      if (kid != null && kid.alpha > best) { best = kid.alpha; sel = i; }
    }
    menuSel = sel;

    var sig:String = labels.join('|');

    if (sig == menuSig && menuPrevSel >= 0 && sel != menuPrevSel) onMenuScroll();
    menuPrevSel = sel;
    if (sig != menuSig)
    {
      menuSig = sig;

      for (t in menuTexts) { sub.remove(t, true); t.destroy(); }
      menuTexts = [];

      var n:Int = labels.length;
      var sc:Float = Math.min(300 / (n * 60), 1);

      for (i in 0...n)
      {
        var opt:FlxText = new FlxText(-640, 0, -1, labels[i]);
        opt.setFormat(Paths.font('liber.ttf'), Std.int(48 * sc), FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        opt.borderSize = 2;
        opt.scrollFactor.set(0, 0);
        opt.y = FlxG.height / 2 + (i * 60 * sc) - opt.height;
        opt.alpha = 0.3;
        sub.add(opt);
        menuTexts.push(opt);
      }
    }

    handleMenuTouch(sub, e);

    for (i in 0...menuTexts.length)
    {
      var o:FlxText = menuTexts[i];
      var isSel:Bool = (i == menuSel);
      o.visible = true;
      o.x = o.x + ((isSel ? 75 : 55) - o.x) * k;
      o.alpha = o.alpha + ((isSel ? 1 : 0.3) - o.alpha) * k;

      if (i == 0 && menuDbg < 12)
      {
        menuDbg++;
      }
    }
  }

  function handleMenuTouch(sub, e:Float):Void
  {
    if (!touchMenu) return;

    if (!touchGroupMoved)
    {
      touchGroupMoved = true;
      try { pauseMenuGroup.y = pauseMenuGroup.y - 5000; } catch (err:Dynamic) {}
    }

    if (touchDelay > 0) { touchDelay -= e; return; }

    var pos = null;
    try
    {
      for (t in FlxG.touches.list)
      {
        if (t.justPressed) { pos = t.getScreenPosition(sub.camera); break; }
      }
    }
    catch (err:Dynamic) {}

    if (pos == null)
    {
      try { if (FlxG.mouse.justPressed) pos = FlxG.mouse.getScreenPosition(sub.camera); }
      catch (err:Dynamic) {}
    }
    if (pos == null) return;

    for (i in 0...menuTexts.length)
    {
      if (!menuTexts[i].overlapsPoint(pos, true, sub.camera)) continue;

      try
      {
        if (i == menuSel) sub.currentMenuEntries[sub.currentEntry].callback(sub);
        else sub.changeSelection(i - menuSel);
      }
      catch (err:Dynamic) { }
      break;
    }
  }

  function onMenuScroll():Void
  {
    try
    {
      for (snd in FlxG.sound.list.members)
      {
        if (snd != null && snd != FlxG.sound.music && snd.playing && snd.time < 150 && snd.length < 3000 && Math.abs(snd.volume - 0.4) < 0.011) snd.stop();
      }
    }
    catch (e:Dynamic) { }

    try { FlxG.sound.play(Paths.sound(PAUSE_SCROLL_SOUND), PAUSE_SCROLL_VOLUME); }
    catch (e:Dynamic) { }
  }

  function updatePauseExtras():Void
  {
    if (pauseSub == null) return;

    var p = PlayState.instance;
    if (p == null || p.subState != pauseSub)
    {
      pauseSub = null;
      practiceText = null;
      return;
    }

    hideVSliceMetadata(pauseSub);
    try { updateCustomMenu(pauseSub); }
    catch (e:Dynamic) { if (!hideErrLogged) { hideErrLogged = true; } }
    if (practiceText != null) practiceText.visible = p.isPracticeMode;
  }

  function fixHudBop():Void
  {
    var p = PlayState.instance;
    if (p == null) return;

    p.hudCameraZoomIntensity = 0.03;
  }

  override function onUpdate(e)
  {
    super.onUpdate(e);

    try
    {
      fixHudBop();
    }
    catch (err:Dynamic)
    {
    }

    if (ps == null) return;

    var misses = Highscore.tallies.missed;
    var score = Math.floor(ps.songScore);

    if (missText != null)
    {
      missText.text = "Score: " + score + " | Misses: " + misses + "/" + maxMisses;
    }

    if (misses > maxMisses && !alreadyKilled)
    {
      alreadyKilled = true;
      ps.health = -1;
    }
  }

  override function onDestroy(event)
  {
    super.onDestroy(event);
    try { if (postUpdateFn != null) FlxG.signals.postUpdate.remove(postUpdateFn); }
    catch (err:Dynamic) {}
    postUpdateFn = null;
  }

  override function onSongRetry(event)
  {
    super.onSongRetry(event);
    pauseActive = false;
    alreadyKilled = false;

    maxMisses = getMaxMissesForDifficulty();

    PauseSubState.musicSuffix = '-defeat';

    if (ps != null && ps.scoreText != null) ps.scoreText.visible = false;
    if (ps != null && ps.healthBar != null) ps.healthBar.visible = false;
    if (ps != null && ps.healthBarBG != null) ps.healthBarBG.visible = false;
    if (ps != null && ps.iconP1 != null) ps.iconP1.visible = false;
    if (ps != null && ps.iconP2 != null) ps.iconP2.visible = false;

    centerPlayerStrumline();
    hideOpponentStrumline();
  }

  function centerPlayerStrumline():Void
  {
    var playerStrumline = PlayState.instance.playerStrumline;
    if (playerStrumline != null)
    {
      playerStrumline.x = FlxG.width / 2 - playerStrumline.width / 2;
      playerStrumline.zIndex = 99999;
    }
  }

  function hideOpponentStrumline():Void
  {
    var opponentStrumline = PlayState.instance.opponentStrumline;
    if (opponentStrumline != null)
    {
      opponentStrumline.visible = false;
      opponentStrumline.alpha = 0;

      if (opponentStrumline.members != null)
      {
        for (arrow in opponentStrumline.members)
        {
          if (arrow != null)
          {
            arrow.visible = false;
            arrow.alpha = 0;
          }
        }
      }
    }
  }
}