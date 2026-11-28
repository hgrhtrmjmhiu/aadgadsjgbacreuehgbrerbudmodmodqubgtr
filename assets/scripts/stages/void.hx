import funkin.play.stage.Stage;
import funkin.play.PlayState;
import funkin.play.GameOverSubState;
import funkin.audio.FunkinSound;
import funkin.Paths;
import funkin.Conductor;
import funkin.Constants;
import funkin.modding.events.ScriptEvent;
import flixel.FlxG;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxTimer;
import funkin.Preferences;
import funkin.util.FlxTweenUtil;
import funkin.play.character.BaseCharacter;
import funkin.play.character.CharacterType;
import openfl.display.BlendMode;
import funkin.graphics.FunkinSprite;
import funkin.data.notestyle.NoteStyleRegistry;

class VoidStage extends Stage
{
  static inline var FADE_TIME:Float = 0.5;
  static inline var SCENE_DURATION:Float = 3.3;

  static inline var PHASE2_BEAT:Int = 68;
  static inline var RETRO_BEAT:Int = 292;
  static inline var RETURN_BEAT:Int = 360;

  static inline var FADE_IN_TIME:Float = 0.7;

  static inline var LIGHT_PROP:String = 'GradienteAdd';
  static inline var LIGHT_PHASE1_ALPHA:Float = 0.6;
  static inline var LIGHT_PHASE2_ALPHA:Float = 0.7;

  static inline var PULSE_PROP:String = 'fondo';
  static inline var GLOW_TOP_PROP:String = 'GradienteArriba';
  static inline var GLOW_BOTTOM_PROP:String = 'GradienteAbajo';

  static inline var BEAT_INTERVAL:Int = 4;
  static inline var PULSE_REST_ALPHA:Float = 0.4;
  static inline var GLOW_REST_ALPHA:Float = 0.6;
  static inline var PULSE_ALPHA_TIME:Float = 0.8;
  static inline var PULSE_SCALE_TIME:Float = 0.8;
  static inline var GLOW_TIME:Float = 0.35;
  static inline var PULSE_SCALE_X:Float = 1.375;
  static inline var PULSE_SCALE_Y:Float = 1.25;

  static inline var NOTE_CAM_ENABLED:Bool = true;
  static inline var NOTE_CAM_DISPLACEMENT:Float = 20;

  var camTurnTimes:Array<Float> = [0, 4800, 9600, 14400, 20400, 25200, 30000, 34800, 39600, 44400, 49200, 54000, 58800, 63600, 68400, 73200, 78000, 82800, 87600, 92400, 97200, 102000, 108000, 112800, 117600, 122400, 127200, 132000, 136800, 141600, 146400, 223200];
  var camTurnFlags:Array<Int> = [0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1];
  var noteCamActive:Bool = false;

  static inline var POPUPS_ENABLED:Bool = true;
  static inline var POPUP_Z:Int = 900;
  static inline var RATING_POP:Float = 0.785 / 0.7;
  static inline var COMBO_POP:Float = 0.6 / 0.5;

  static inline var RATING_BOX_W:Float = 179;
  static inline var RATING_BOX_H:Float = 66;
  static inline var RATING_CX:Float = 1037.5;
  static inline var RATING_CY:Float = 102;

  static inline var COMBO_BOX:Float = 38;
  static inline var COMBO_CX0:Float = 1007;
  static inline var COMBO_PITCH:Float = 29;
  static inline var COMBO_CY:Float = 152;
  static inline var MIN_DIGITS:Int = 3;
  static inline var POPUP_TWEEN_TIME:Float = 0.5;
  var popRating = null;
  var popNums:Array<Dynamic> = [];

  var ps:PlayState;
  var sequenceStarted:Bool = false;
  var allowFinalDeath:Bool = false;
  var dadSceneAnim:String = 'idle';

  var currentPhase:Int = 0;
  var pulse = null;
  var fondoNegro = null;
  var glowTop = null;
  var glowBottom = null;
  var glowRojo = null;
  var lightAdd = null;
  var baseScaleX:Float = 1;
  var baseScaleY:Float = 1;
  var scaleCaptured:Bool = false;
  var warnedFlashing:Bool = false;

  var exclusiveNames:Array<String> = ['basura', 'props1', 'props2', 'subtract', 'GradienteArriba', 'GradienteAbajo'];
  var exclusiveProps:Array<Dynamic> = [];
  var exclusiveFull:Array<Float> = [];

  var negroSnap:Array<Float> = null;
  var fondoSnap:Array<Float> = null;
  var fondoBlend = null;
  var bfSnap:Array<Float> = null;
  var dadSnap:Array<Float> = null;
  var gfSnap:Array<Float> = null;

  function new()
  {
    super('void');
  }

  override function onCreate(event:ScriptEvent):Void
  {
    super.onCreate(event);

    bindProps();
    currentPhase = 0;
    applyPhase(1);
    resetPopups();

    GameOverSubState.musicSuffix = '-defeat';
    GameOverSubState.blueBallSuffix = '-defeat';

    ps = PlayState.instance;
    sequenceStarted = false;
    allowFinalDeath = false;
    dadSceneAnim = 'idle';
  }

  override function onNoteGhostMiss(event):Void
  {
    super.onNoteGhostMiss(event);

    event.cancel();
    event.stopPropagation();
  }

  override function onGameOver(event:ScriptEvent):Void
  {
    super.onGameOver(event);

    ps = PlayState.instance;

    if (allowFinalDeath)
    {
      try
      {
        if (ps != null && ps.camHUD != null)
          ps.camHUD.alpha = 1;
      }
      catch (e:Dynamic)
      {
      }

      return;
    }

    if (currentPhase == 3 && !sequenceStarted)
      return;

    if (sequenceStarted)
    {
      event.cancel();
      return;
    }

    event.cancel();
    sequenceStarted = true;

    if (ps == null)
      return;

    ps.isPlayerDying = true;
    ps.isInCutscene = true;

    focusCameraOnGFAndZoom();

    if (ps.currentStage != null)
    {
      var dad = ps.currentStage.getDad();

      if (dad != null)
      {
        dad.holdTimer = 0;
        dad.playAnimation('idle', true);
      }
    }

    if (FlxG.sound.music != null)
    {
      try { FlxG.sound.music.onComplete = function() {}; } catch (e:Dynamic) {}
      try { FlxG.sound.music.resume(); } catch (e:Dynamic) {}

      try
      {
        FlxTween.tween(FlxG.sound.music, {volume: 0}, FADE_TIME, {ease: FlxEase.linear});
      }
      catch (e:Dynamic) {}
    }

    if (ps.vocals != null)
    {
      try { ps.vocals.resume(); } catch (e:Dynamic) {}

      try
      {
        FlxTween.tween(ps.vocals, {playerVolume: 0, opponentVolume: 0}, FADE_TIME, {ease: FlxEase.linear});
      }
      catch (e:Dynamic) {}
    }

    if (ps.camHUD != null)
    {
      FlxTween.tween(
        ps.camHUD,
        {alpha: 0},
        FADE_TIME,
        {ease: FlxEase.linear}
      );
    }

    FunkinSound.playOnce(Paths.sound('defeat_prekill_sfx'));

    new FlxTimer().start(FADE_TIME, function(_)
    {
      try { if (FlxG.sound.music != null) FlxG.sound.music.pause(); } catch (e:Dynamic) {}
      try { if (ps != null && ps.vocals != null) ps.vocals.pause(); } catch (e:Dynamic) {}
    });

    new FlxTimer().start(0.22, function(_)
    {
      if (ps == null || ps.currentStage == null)
        return;

      var dad = ps.currentStage.getDad();

      dadSceneAnim = 'kill';

      if (dad != null)
        dad.playAnimation('kill', true);
    });

    new FlxTimer().start(1.80, function(_)
    {
      if (ps == null || ps.currentStage == null)
        return;

      var dad = ps.currentStage.getDad();

      dadSceneAnim = 'kill2';

      if (dad != null)
        dad.playAnimation('kill2', true);
    });

    new FlxTimer().start(SCENE_DURATION, function(_)
    {
      if (ps == null)
        return;

      allowFinalDeath = true;
      ps.isInCutscene = false;
      ps.isPlayerDying = false;
    });
  }

  override function onCountdownStart(event):Void
  {
    super.onCountdownStart(event);
    resetPopups();

    try
    {
      ps = PlayState.instance;
      if (ps == null || ps.currentStage == null) return;

      var gf = ps.currentStage.getGirlfriend();
      if (gf == null) return;

      ps.cancelCameraFollowTween();
      ps.cameraFollowPoint.setPosition(gf.cameraFocusPoint.x, gf.cameraFocusPoint.y);
      ps.resetCamera(false, true, true);
    }
    catch (e:Dynamic)
    {
    }
  }

  function focusCameraOnGFAndZoom():Void
  {
    if (ps == null || ps.currentStage == null)
      return;

    var gf = ps.currentStage.getGirlfriend();

    if (gf == null)
      return;

    ps.resetCamera(false, false, false);
    ps.cancelCameraFollowTween();

    ps.cameraFollowPoint.setPosition(
      gf.cameraFocusPoint.x,
      gf.cameraFocusPoint.y
    );

    var durationSeconds =
      Conductor.instance.stepLengthMs * 7 / Constants.MS_PER_SEC;

    ps.tweenCameraZoom(
      0.6,
      durationSeconds,
      true,
      FlxEase.quadInOut
    );
  }

  override function onSongEvent(event):Void
  {
    super.onSongEvent(event);

    if (sequenceStarted && !allowFinalDeath)
      event.cancel();
  }

  override function onSongRetry(event):Void
  {
    super.onSongRetry(event);
    resetPopups();

    ps = PlayState.instance;

    sequenceStarted = false;
    allowFinalDeath = false;
    dadSceneAnim = 'idle';

    try
    {
      if (ps != null)
      {
        ps.isInCutscene = false;
        ps.isPlayerDying = false;

        if (ps.camHUD != null)
        {
          FlxTween.cancelTweensOf(ps.camHUD);
          ps.camHUD.alpha = 1;
        }

        if (ps.vocals != null)
        {
          FlxTween.cancelTweensOf(ps.vocals);
          ps.vocals.playerVolume = 1;
          ps.vocals.opponentVolume = 1;
        }
      }
    }
    catch (e:Dynamic)
    {
    }

    try
    {
      if (FlxG.sound.music != null)
      {
        FlxTween.cancelTweensOf(FlxG.sound.music);
        FlxG.sound.music.volume = 1;
      }
    }
    catch (e:Dynamic)
    {
    }

    resetStageState();

    try
    {
      if (ps != null && ps.currentStage != null)
      {
        var gf = ps.currentStage.getGirlfriend();
        if (gf != null) ps.cameraFollowPoint.setPosition(gf.cameraFocusPoint.x, gf.cameraFocusPoint.y);
      }
    }
    catch (e:Dynamic)
    {
    }

    GameOverSubState.musicSuffix = '-defeat';
    GameOverSubState.blueBallSuffix = '-defeat';
  }

  function resetPopups():Void
  {
    popRating = null;
    popNums = [];
  }

  override function onNoteHit(event):Void
  {
    super.onNoteHit(event);

    if (!POPUPS_ENABLED) return;

    try
    {
      var p = PlayState.instance;
      if (p == null) return;

      if (p.comboPopUps != null) p.comboPopUps.visible = false;

      var note = event.note;
      if (note == null || note.noteData == null || !note.noteData.getMustHitNote()) return;
      if (!note.scoreable) return;

      var judgement:String = event.judgement;
      if (judgement == null || judgement == 'miss') return;

      showOriginalPopup(p, judgement, event.comboCount);
    }
    catch (e:Dynamic)
    {
    }
  }

  function popupStyle()
  {
    var p = PlayState.instance;
    var id:String = (p != null && p.currentChart != null) ? p.currentChart.noteStyle : '';
    return NoteStyleRegistry.instance.fetchEntry(id);
  }

  function dropPopup(spr):Void
  {
    if (spr == null) return;
    try
    {
      FlxTween.cancelTweensOf(spr);
      FlxTween.cancelTweensOf(spr.scale);
      spr.visible = false;
      PlayState.instance.remove(spr, true);
      spr.destroy();
    }
    catch (e:Dynamic) {}
  }

  function placePopup(p, spr, cx:Float, cy:Float, boxW:Float, boxH:Float, pop:Float, stepSeconds:Float):Void
  {
    spr.cameras = [p.camHUD];
    spr.zIndex = POPUP_Z;
    spr.scrollFactor.set(0, 0);
    spr.alpha = 1;
    spr.acceleration.set(0, 0);
    spr.velocity.set(0, 0);

    var fw:Float = spr.frameWidth;
    var fh:Float = spr.frameHeight;
    var fit:Float = Math.min(boxW / fw, boxH / fh);

    spr.scale.set(1, 1);
    spr.updateHitbox();
    spr.x = cx - fw / 2;
    spr.y = cy - fh / 2;

    spr.scale.set(fit * pop, fit * pop);

    p.add(spr);

    FlxTween.tween(spr.scale, {x: fit, y: fit}, POPUP_TWEEN_TIME, {ease: FlxEase.expoOut});
    FlxTween.tween(spr, {alpha: 0}, POPUP_TWEEN_TIME, {startDelay: stepSeconds, ease: FlxEase.expoOut});
  }

  function showOriginalPopup(p, judgement:String, combo:Int):Void
  {
    var style = popupStyle();
    if (style == null) return;

    var stepSeconds:Float = Conductor.instance.stepLengthMs * 0.01;

    dropPopup(popRating);
    popRating = style.buildJudgementSprite(judgement);
    if (popRating != null)
    {
      placePopup(p, popRating, RATING_CX, RATING_CY, RATING_BOX_W, RATING_BOX_H, RATING_POP, stepSeconds);
    }

    for (num in popNums) dropPopup(num);
    popNums = [];

    var digits:Array<Int> = [];
    var n:Int = combo;
    while (n > 0)
    {
      digits.unshift(n % 10);
      n = Math.floor(n / 10);
    }
    while (digits.length < MIN_DIGITS) digits.unshift(0);

    for (i in 0...digits.length)
    {
      var num = style.buildComboNumSprite(digits[i]);
      if (num == null) continue;

      placePopup(p, num, COMBO_CX0 + COMBO_PITCH * i, COMBO_CY, COMBO_BOX, COMBO_BOX, COMBO_POP, stepSeconds);
      popNums.push(num);
    }
  }

  override function addCharacter(character:BaseCharacter, charType:CharacterType):Void
  {
    super.addCharacter(character, charType);

    var key:String = characterKey(character);
    if (key == null) return;

    if (currentPhase <= 1) return;

    placeCharacter(character, charValues(currentPhase, key));
    refresh();
  }

  function singDisplacement(character, out:Array<Float>):Void
  {
    out[0] = 0;
    out[1] = 0;
    if (character == null) return;

    var name:String = character.getCurrentAnimation();
    if (name == null || name.indexOf('sing') != 0) return;

    var dir:String = name.substr(4).split('-')[0].toLowerCase();
    if (dir == 'up') out[1] = -NOTE_CAM_DISPLACEMENT;
    else if (dir == 'down') out[1] = NOTE_CAM_DISPLACEMENT;
    else if (dir == 'left') out[0] = -NOTE_CAM_DISPLACEMENT;
    else if (dir == 'right') out[0] = NOTE_CAM_DISPLACEMENT;
  }

  function updateNoteCamera():Void
  {
    var p = PlayState.instance;
    var blocked:Bool = !NOTE_CAM_ENABLED || p == null || p.currentStage == null || p.isInCutscene || p.isPlayerDying || sequenceStarted;

    if (blocked)
    {
      if (noteCamActive && FlxG.camera != null) FlxG.camera.targetOffset.set(0, 0);
      noteCamActive = false;
      return;
    }

    var dad = p.currentStage.getDad();
    var bf = p.currentStage.getBoyfriend();
    var pos:Float = Conductor.instance.songPosition;

    var turn:Int = 0;
    for (i in 0...camTurnTimes.length)
    {
      if (camTurnTimes[i] <= pos) turn = camTurnFlags[i];
      else break;
    }

    var target = (turn == 1) ? bf : dad;

    var disp:Array<Float> = [0, 0];
    singDisplacement(target, disp);

    FlxG.camera.targetOffset.set(disp[0], disp[1]);
    noteCamActive = (disp[0] != 0 || disp[1] != 0) || noteCamActive;
  }

  override function onUpdate(event):Void
  {
    super.onUpdate(event);

    try
    {
      updateNoteCamera();
    }
    catch (e:Dynamic)
    {
    }
  }

  override function onBeatHit(event):Void
  {
    super.onBeatHit(event);

    try
    {
      var target:Int = phaseForBeat(event.beat);
      if (target != currentPhase) applyPhase(target);

      if (event.beat % BEAT_INTERVAL == 0) pulseOnBeat(event.beat);
    }
    catch (e:Dynamic)
    {
      try { bindProps(); } catch (e2:Dynamic) {}
    }
  }

  override function onPause(event):Void
  {
    super.onPause(event);

    try
    {
      if (pulse != null)
      {
        FlxTweenUtil.pauseTweensOf(pulse);
        FlxTweenUtil.pauseTweensOf(pulse.scale);
      }
      if (glowTop != null) FlxTweenUtil.pauseTweensOf(glowTop);
      if (glowBottom != null) FlxTweenUtil.pauseTweensOf(glowBottom);
      for (prop in exclusiveProps) FlxTweenUtil.pauseTweensOf(prop);
    }
    catch (e:Dynamic)
    {
    }
  }

  override function onResume(event):Void
  {
    super.onResume(event);

    try
    {
      if (pulse != null)
      {
        FlxTweenUtil.resumeTweensOf(pulse);
        FlxTweenUtil.resumeTweensOf(pulse.scale);
      }
      if (glowTop != null) FlxTweenUtil.resumeTweensOf(glowTop);
      if (glowBottom != null) FlxTweenUtil.resumeTweensOf(glowBottom);
      for (prop in exclusiveProps) FlxTweenUtil.resumeTweensOf(prop);
    }
    catch (e:Dynamic)
    {
    }
  }

  function phaseForBeat(beat:Int):Int
  {
    if (beat >= RETURN_BEAT) return 2;
    if (beat >= RETRO_BEAT) return 3;
    if (beat >= PHASE2_BEAT) return 2;
    return 1;
  }

  function fullAlpha(name:String):Float
  {
    if (name == 'GradienteArriba' || name == 'GradienteAbajo') return 0.6;
    return 1;
  }

  function charValues(phase:Int, key:String):Array<Float>
  {
    if (phase <= 1)
    {
      if (key == 'bf') return [-300, 0, 1];
      if (key == 'dad') return [300, 0, 2];
      return [0, 0, 100];
    }

    if (phase == 3)
    {
      if (key == 'bf') return [-300, 0, 300];
      if (key == 'dad') return [200, 0, 200];
      return [0, 0, 100];
    }

    if (key == 'bf') return [-300, 0, 100];
    if (key == 'dad') return [200, 0, 200];
    return [0, 0, 50];
  }

  function characterKey(character):String
  {
    if (character == getBoyfriend()) return 'bf';
    if (character == getDad()) return 'dad';
    if (character == getGirlfriend()) return 'gf';
    return null;
  }

  function bindProps():Void
  {
    fondoNegro = getNamedProp('fondonegro');
    pulse = getNamedProp(PULSE_PROP);
    glowTop = getNamedProp(GLOW_TOP_PROP);
    glowBottom = getNamedProp(GLOW_BOTTOM_PROP);
    glowRojo = getNamedProp('glowrojo');
    lightAdd = getNamedProp(LIGHT_PROP);

    exclusiveProps = [];
    exclusiveFull = [];
    for (name in exclusiveNames)
    {
      var prop = getNamedProp(name);
      if (prop != null)
      {
        exclusiveProps.push(prop);
        exclusiveFull.push(fullAlpha(name));
      }
    }

    if (pulse != null && !scaleCaptured)
    {
      scaleCaptured = true;
      baseScaleX = pulse.scale.x;
      baseScaleY = pulse.scale.y;
    }

    if (fondoNegro != null && negroSnap == null)
    {
      negroSnap = [fondoNegro.x, fondoNegro.y, fondoNegro.alpha, fondoNegro.scrollFactor.x, fondoNegro.scrollFactor.y, fondoNegro.zIndex];
    }

    if (pulse != null && fondoSnap == null)
    {
      fondoSnap = [pulse.x, pulse.y, pulse.alpha, pulse.scrollFactor.x, pulse.scrollFactor.y, pulse.zIndex];
      fondoBlend = pulse.blend;
    }
  }

  function applyPhase(newPhase:Int):Void
  {
    var previous:Int = currentPhase;
    if (newPhase == previous) return;
    currentPhase = newPhase;

    if (newPhase == 1) restoreSharedProps();
    else applyDefeat2Shared(newPhase == 2);

    for (i in 0...exclusiveProps.length)
    {
      var prop = exclusiveProps[i];
      FlxTween.cancelTweensOf(prop, ['alpha']);

      if (newPhase != 2)
      {
        prop.alpha = 0;
      }
      else if (previous == 1)
      {
        prop.alpha = 0;
        FlxTween.tween(prop, {alpha: exclusiveFull[i]}, FADE_IN_TIME, {ease: FlxEase.quadInOut});
      }
      else
      {
        prop.alpha = exclusiveFull[i];
      }
    }

    if (lightAdd != null)
    {
      FlxTween.cancelTweensOf(lightAdd, ['alpha']);

      if (newPhase == 1) lightAdd.alpha = LIGHT_PHASE1_ALPHA;
      else if (newPhase == 2) lightAdd.alpha = LIGHT_PHASE2_ALPHA;
      else lightAdd.alpha = 0;
    }

    if (glowRojo != null)
    {
      FlxTween.cancelTweensOf(glowRojo, ['alpha']);
      glowRojo.alpha = (newPhase == 3) ? 1 : 0;
    }

    if (newPhase == 1)
    {
      setZ(getBoyfriend(), charValues(1, 'bf'));
      setZ(getDad(), charValues(1, 'dad'));
      setZ(getGirlfriend(), charValues(1, 'gf'));
    }
    else
    {
      placeCharacter(getBoyfriend(), charValues(newPhase, 'bf'));
      placeCharacter(getDad(), charValues(newPhase, 'dad'));
      placeCharacter(getGirlfriend(), charValues(newPhase, 'gf'));
    }

    refresh();
  }

  function restoreSharedProps():Void
  {
    if (fondoNegro != null && negroSnap != null)
    {
      fondoNegro.x = negroSnap[0];
      fondoNegro.y = negroSnap[1];
      fondoNegro.alpha = negroSnap[2];
      fondoNegro.scrollFactor.set(negroSnap[3], negroSnap[4]);
      fondoNegro.zIndex = Std.int(negroSnap[5]);
    }

    if (pulse != null && fondoSnap != null)
    {
      FlxTween.cancelTweensOf(pulse);
      FlxTween.cancelTweensOf(pulse.scale);
      pulse.scale.set(baseScaleX, baseScaleY);

      pulse.x = fondoSnap[0];
      pulse.y = fondoSnap[1];
      pulse.alpha = fondoSnap[2];
      pulse.scrollFactor.set(fondoSnap[3], fondoSnap[4]);
      pulse.zIndex = Std.int(fondoSnap[5]);
      pulse.blend = fondoBlend;
    }
  }

  function applyDefeat2Shared(showFondo:Bool):Void
  {
    if (fondoNegro != null)
    {
      fondoNegro.x = -4201;
      fondoNegro.y = -2462;
      fondoNegro.zIndex = 0;
    }

    if (pulse != null)
    {
      FlxTween.cancelTweensOf(pulse);
      FlxTween.cancelTweensOf(pulse.scale);
      pulse.scale.set(baseScaleX, baseScaleY);

      pulse.x = -1428;
      pulse.y = -188.5;
      pulse.scrollFactor.set(0.8, 0.8);
      pulse.blend = BlendMode.NORMAL;
      pulse.zIndex = 10;
      pulse.alpha = showFondo ? PULSE_REST_ALPHA : 0;
    }
  }

  function placeCharacter(character, v:Array<Float>):Void
  {
    if (character == null || v == null) return;

    character.zIndex = Std.int(v[2]);

    character.resetCameraFocusPoint();
    character.cameraFocusPoint.x += v[0];
    character.cameraFocusPoint.y += v[1];
  }

  function setZ(character, v:Array<Float>):Void
  {
    if (character == null || v == null) return;
    character.zIndex = Std.int(v[2]);
  }

  function restoreCharacter(character, snap:Array<Float>):Void
  {
    if (character == null || snap == null) return;

    character.zIndex = Std.int(snap[0]);
    character.cameraFocusPoint.x = snap[3];
    character.cameraFocusPoint.y = snap[4];
  }

  function pulseOnBeat(beat:Int):Void
  {
    var flashing:Bool = flashingEnabled();

    if (pulse != null && pulse.alpha > 0.01) pulseBackground(flashing);
    if (glowTop != null && glowTop.alpha > 0.01) pulseGlow(glowTop, flashing);
    if (glowBottom != null && glowBottom.alpha > 0.01) pulseGlow(glowBottom, flashing);
  }

  function pulseBackground(flashing:Bool):Void
  {
    FlxTween.cancelTweensOf(pulse, ['alpha']);
    pulse.alpha = flashing ? 0.5 : 0.45;
    FlxTween.tween(pulse, {alpha: PULSE_REST_ALPHA}, flashing ? PULSE_ALPHA_TIME : PULSE_ALPHA_TIME / 2, {ease: FlxEase.bounceOut});

    if (flashing)
    {
      FlxTween.cancelTweensOf(pulse.scale, ['x', 'y']);
      pulse.scale.set(baseScaleX * PULSE_SCALE_X, baseScaleY * PULSE_SCALE_Y);
      FlxTween.tween(pulse.scale, {x: baseScaleX, y: baseScaleY}, PULSE_SCALE_TIME, {ease: FlxEase.sineOut});
    }
  }

  function pulseGlow(glow, flashing:Bool):Void
  {
    FlxTween.cancelTweensOf(glow, ['alpha']);
    glow.alpha = flashing ? 1 : 0.7;
    FlxTween.tween(glow, {alpha: GLOW_REST_ALPHA}, GLOW_TIME, {ease: FlxEase.bounceOut});
  }

  function resetStageState():Void
  {
    try
    {
      if (glowTop != null) FlxTween.cancelTweensOf(glowTop);
      if (glowBottom != null) FlxTween.cancelTweensOf(glowBottom);

      currentPhase = 0;
      applyPhase(1);
    }
    catch (e:Dynamic)
    {
    }
  }

  function flashingEnabled():Bool
  {
    var value = null;

    try
    {
      value = Preferences.flashingLights;
    }
    catch (e:Dynamic)
    {
      if (!warnedFlashing)
      {
        warnedFlashing = true;
      }
    }

    return value != false;
  }
}
