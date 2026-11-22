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

class VoidStage extends Stage
{
  static inline var FADE_TIME:Float = 0.5;
  static inline var SCENE_DURATION:Float = 3.3;

  // >>> FASES DEL STAGE "void" Y PULSO POR BEAT (portado de defeat.hx de VS IMPOSTOR LEGACY)
  // BPM 200 -> 300 ms por beat. Fase 1 = defeat1, fase 2 = defeat2, fase 3 = defeat3 (retro).
  static inline var PHASE2_BEAT:Int = 68; // Defeat Fade (20.4 s)
  static inline var RETRO_BEAT:Int = 292; // entra el retro (87.6 s)
  static inline var RETURN_BEAT:Int = 360; // sale del retro y vuelve a la fase 2 (108.0 s)

  // Fade de aparicion de los props nuevos de defeat2 (el del original).
  static inline var FADE_IN_TIME:Float = 0.7;

  // "GradienteAdd" (iluminao omaga, Add) ya estaba visible desde el inicio en el original (alpha 0.6) y sube a 0.7 con el Defeat Fade.
  static inline var LIGHT_PROP:String = 'GradienteAdd';
  static inline var LIGHT_PHASE1_ALPHA:Float = 0.6;
  static inline var LIGHT_PHASE2_ALPHA:Float = 0.7;

  // Nombres de los props en el JSON del stage.
  static inline var PULSE_PROP:String = 'fondo';
  static inline var GLOW_TOP_PROP:String = 'GradienteArriba';
  static inline var GLOW_BOTTOM_PROP:String = 'GradienteAbajo';

  // Valores del pulso, los del original. Si el pulso te parece lento, baja los tiempos.
  static inline var BEAT_INTERVAL:Int = 4;
  static inline var PULSE_REST_ALPHA:Float = 0.4;
  static inline var GLOW_REST_ALPHA:Float = 0.6;
  static inline var PULSE_ALPHA_TIME:Float = 0.8;
  static inline var PULSE_SCALE_TIME:Float = 0.8;
  static inline var GLOW_TIME:Float = 0.35;
  static inline var PULSE_SCALE_X:Float = 1.375;
  static inline var PULSE_SCALE_Y:Float = 1.25;

  // Escribe una linea en el log en cada pulso. Ponlo en false cuando ya funcione.
  static inline var PULSE_DEBUG_LOG:Bool = true;
  // Movimiento de cámara al cantar (como NightmareVision): la cámara se desplaza hacia la flecha del personaje
  // al que sigue y vuelve cuando termina la animación. 20 es el valor por defecto del original (camDisplacement).
  static inline var NOTE_CAM_ENABLED:Bool = true;
  static inline var NOTE_CAM_DISPLACEMENT:Float = 20;
  // A quién sigue la cámara en cada momento, sacado de mustHitSection del chart de NightmareVision
  // (0 = oponente/dad, 1 = jugador/bf). Cada entrada vale desde su tiempo (ms) hasta la siguiente.
  var camTurnTimes:Array<Float> = [0, 4800, 9600, 14400, 20400, 25200, 30000, 34800, 39600, 44400, 49200, 54000, 58800, 63600, 68400, 73200, 78000, 82800, 87600, 92400, 97200, 102000, 108000, 112800, 117600, 122400, 127200, 132000, 136800, 141600, 146400, 223200];
  var camTurnFlags:Array<Int> = [0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1];
  var noteCamActive:Bool = false;

  // <<< FASES DEL STAGE "void" Y PULSO POR BEAT

  var ps:PlayState;
  var sequenceStarted:Bool = false;
  var allowFinalDeath:Bool = false;
  var dadSceneAnim:String = 'idle';

  // Fases y pulso.
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

  // Props que no estaban en la fase 1 (aparecen con fade en la fase 2).
  var exclusiveNames:Array<String> = ['basura', 'props1', 'props2', 'subtract', 'GradienteArriba', 'GradienteAbajo'];
  var exclusiveProps:Array<Dynamic> = [];
  var exclusiveFull:Array<Float> = [];

  // Valores de la fase 1 (los del JSON) de los props compartidos y de los personajes, para volver a ellos al reintentar.
  // Props: [x, y, alpha, scrollX, scrollY, zIndex]. Personajes: [zIndex, x, y, focoX, focoY].
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

    // Fases y pulso: buscar los props (ya existen, super.onCreate construyó el stage) y dejar la fase 1.
    bindProps();
    currentPhase = 0;
    applyPhase(1);

    // Código original del stage.
    GameOverSubState.musicSuffix = '-defeat';
    GameOverSubState.blueBallSuffix = '-defeat';

    // Preparar la secuencia de muerte.
    ps = PlayState.instance;
    sequenceStarted = false;
    allowFinalDeath = false;
    dadSceneAnim = 'idle';
  }

  override function onNoteGhostMiss(event):Void
  {
    super.onNoteGhostMiss(event);

    // Código original: cancelar las ghost misses.
    event.cancel();
    event.stopPropagation();
  }

  override function onGameOver(event:ScriptEvent):Void
  {
    super.onGameOver(event);

    // >>> EMPIEZA LO NUEVO
    // Siempre trabajar con el PlayState actual (ps puede ser uno viejo/destruido).
    ps = PlayState.instance;

    if (allowFinalDeath)
    {
      // Restaurar el HUD antes del Game Over real; protegido por si la cámara ya no es válida.
      try
      {
        if (ps != null && ps.camHUD != null)
          ps.camHUD.alpha = 1;
      }
      catch (e:Dynamic)
      {
        trace('[Defeat2] camHUD.alpha falló en onGameOver: ' + e);
      }

      return;
    }
    // <<< TERMINA LO NUEVO

    if (sequenceStarted)
    {
      event.cancel();
      return;
    }

    // Evitar que el Game Over normal interrumpa la escena.
    event.cancel();
    sequenceStarted = true;

    if (ps == null)
      return;

    ps.isPlayerDying = true;
    ps.isInCutscene = true;

    // Enfocar a GF y aplicar el zoom.
    focusCameraOnGFAndZoom();

    // Mantener al oponente en idle hasta su animación de muerte.
    if (ps.currentStage != null)
    {
      var dad = ps.currentStage.getDad();

      if (dad != null)
      {
        dad.holdTimer = 0;
        dad.playAnimation('idle', true);
      }
    }

    // >>> EMPIEZA LO NUEVO
    // Cada llamada de audio va protegida: el "Null Object Reference" salía en ps.vocals.resume()
    // (línea 117 de tu versión). Si algún sonido del grupo de voces no es válido, ya no rompe la secuencia.
    // Desvanecer la música instrumental.
    if (FlxG.sound.music != null)
    {
      try { FlxG.sound.music.onComplete = function() {}; } catch (e:Dynamic) { trace('[Defeat2] music.onComplete falló: ' + e); }
      try { FlxG.sound.music.resume(); } catch (e:Dynamic) { trace('[Defeat2] music.resume falló: ' + e); }

      try
      {
        FlxTween.tween(FlxG.sound.music, {volume: 0}, FADE_TIME, {ease: FlxEase.linear});
      }
      catch (e:Dynamic) { trace('[Defeat2] fade música falló: ' + e); }
    }

    // Desvanecer las voces.
    if (ps.vocals != null)
    {
      try { ps.vocals.resume(); } catch (e:Dynamic) { trace('[Defeat2] vocals.resume falló: ' + e); }

      try
      {
        FlxTween.tween(ps.vocals, {playerVolume: 0, opponentVolume: 0}, FADE_TIME, {ease: FlxEase.linear});
      }
      catch (e:Dynamic) { trace('[Defeat2] fade voces falló: ' + e); }
    }
    // <<< TERMINA LO NUEVO

    // Ocultar el HUD durante la escena.
    if (ps.camHUD != null)
    {
      FlxTween.tween(
        ps.camHUD,
        {alpha: 0},
        FADE_TIME,
        {ease: FlxEase.linear}
      );
    }

    // Sonido inicial de la secuencia.
    FunkinSound.playOnce(Paths.sound('defeat_prekill_sfx'));

    // Pausar el audio cuando termine el fundido.
    new FlxTimer().start(FADE_TIME, function(_)
    {
      // >>> EMPIEZA LO NUEVO
      try { if (FlxG.sound.music != null) FlxG.sound.music.pause(); } catch (e:Dynamic) { trace('[Defeat2] music.pause falló: ' + e); }
      try { if (ps != null && ps.vocals != null) ps.vocals.pause(); } catch (e:Dynamic) { trace('[Defeat2] vocals.pause falló: ' + e); }
      // <<< TERMINA LO NUEVO
    });

    // Primera animación de muerte del oponente.
    new FlxTimer().start(0.22, function(_)
    {
      if (ps == null || ps.currentStage == null)
        return;

      var dad = ps.currentStage.getDad();

      dadSceneAnim = 'kill';

      if (dad != null)
        dad.playAnimation('kill', true);
    });

    // Segunda animación de muerte.
    new FlxTimer().start(1.80, function(_)
    {
      if (ps == null || ps.currentStage == null)
        return;

      var dad = ps.currentStage.getDad();

      dadSceneAnim = 'kill2';

      if (dad != null)
        dad.playAnimation('kill2', true);
    });

    // Al terminar la escena, permitir el Game Over normal.
    new FlxTimer().start(SCENE_DURATION, function(_)
    {
      if (ps == null)
        return;

      allowFinalDeath = true;
      ps.isInCutscene = false;
      ps.isPlayerDying = false;
    });
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

    // Evitar que eventos de la canción interfieran con la escena.
    if (sequenceStarted && !allowFinalDeath)
      event.cancel();
  }

  override function onSongRetry(event):Void
  {
    super.onSongRetry(event);

    // >>> EMPIEZA LO NUEVO
    // Tras reintentar, PlayState es una instancia nueva: la referencia vieja (ps) apunta a una
    // cámara destruida, de ahí el "Invalid access to field alpha". Se refresca y se protege cada acceso.
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
      trace('[Defeat2] restaurar estado en onSongRetry falló: ' + e);
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
      trace('[Defeat2] restaurar música en onSongRetry falló: ' + e);
    }
    // <<< TERMINA LO NUEVO

    // Fases y pulso: volver a la fase 1.
    resetStageState();

    // Conservar la configuración original y adicional.
    GameOverSubState.musicSuffix = '-defeat';
    GameOverSubState.blueBallSuffix = '-defeat';
  }

  // >>> FASES DEL STAGE "void" Y PULSO POR BEAT
  override function addCharacter(character:BaseCharacter, charType:CharacterType):Void
  {
    super.addCharacter(character, charType);

    var key:String = characterKey(character);
    if (key == null) return;

    // Fase 1: el motor ya dejó el personaje y su foco de cámara bien (al crear y en resetStage); no se toca.
    if (currentPhase <= 1) return;

    // Personaje que entra a mitad de la canción (cambio de personaje): recibe los valores de la fase actual.
    placeCharacter(character, charValues(currentPhase, key));
    refresh();
  }

  // Desplazamiento según la animación actual (singUP/DOWN/LEFT/RIGHT y sus -hold; los miss no mueven).
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

    // Personaje seguido según el turno del chart original (mustHitSection).
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
      trace('[Void] cámara por nota falló: ' + e);
    }
  }

  override function onBeatHit(event):Void
  {
    super.onBeatHit(event);

    // Si algo falla (por ejemplo, props ya destruidos tras un reintento), se registra y se vuelven a buscar los props.
    try
    {
      var target:Int = phaseForBeat(event.beat);
      if (target != currentPhase) applyPhase(target);

      if (event.beat % BEAT_INTERVAL == 0) pulseOnBeat(event.beat);
    }
    catch (e:Dynamic)
    {
      trace('[Void] falló en el beat ' + event.beat + ': ' + e);
      try { bindProps(); } catch (e2:Dynamic) { trace('[Void] volver a buscar los props falló: ' + e2); }
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
      trace('[Void] pausar los tweens falló: ' + e);
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
      trace('[Void] reanudar los tweens falló: ' + e);
    }
  }

  // Fase segun el beat: 1 = defeat1, 2 = defeat2, 3 = retro (defeat3). Despues del retro vuelve a la 2.
  function phaseForBeat(beat:Int):Int
  {
    if (beat >= RETURN_BEAT) return 2;
    if (beat >= RETRO_BEAT) return 3;
    if (beat >= PHASE2_BEAT) return 2;
    return 1;
  }

  // Alpha "completo" de cada prop exclusivo de defeat2 (los mismos valores del JSON).
  function fullAlpha(name:String):Float
  {
    if (name == 'GradienteArriba' || name == 'GradienteAbajo') return 0.6;
    return 1;
  }

  // Valores de los personajes por fase: [offsetCamaraX, offsetCamaraY, zIndex]. La posición x/y ya NO se toca: sale del JSON del stage.
  function charValues(phase:Int, key:String):Array<Float>
  {
    // Fase 1: mismos valores que void.json (cámara bf [-300,0], dad [300,0]; z bf 1, dad 2, gf 100).
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

    // Valores de la fase 1 (los del JSON), solo la primera vez.
    if (fondoNegro != null && negroSnap == null)
    {
      negroSnap = [fondoNegro.x, fondoNegro.y, fondoNegro.alpha, fondoNegro.scrollFactor.x, fondoNegro.scrollFactor.y, fondoNegro.zIndex];
    }

    if (pulse != null && fondoSnap == null)
    {
      fondoSnap = [pulse.x, pulse.y, pulse.alpha, pulse.scrollFactor.x, pulse.scrollFactor.y, pulse.zIndex];
      fondoBlend = pulse.blend;
    }

    trace('[Void] props encontrados -> fondonegro: ' + (fondoNegro != null) + ', fondo: ' + (pulse != null) + ', glowrojo: ' + (glowRojo != null) + ', ' + LIGHT_PROP + ': ' + (lightAdd != null) + ', exclusivos de defeat2: ' + exclusiveProps.length + ' de ' + exclusiveNames.length);
  }

  // Cambia de fase. Los cambios de valores son instantaneos; solo los props nuevos de defeat2 aparecen con fade.
  function applyPhase(newPhase:Int):Void
  {
    var previous:Int = currentPhase;
    if (newPhase == previous) return;
    currentPhase = newPhase;

    trace('[Void] fase ' + newPhase + ' (antes: ' + previous + ')');

    // fondonegro y fondo (ya existian en defeat1).
    if (newPhase == 1) restoreSharedProps();
    else applyDefeat2Shared(newPhase == 2);

    // Props exclusivos de defeat2.
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
        // Props nuevos: aparecen con el fade del original.
        prop.alpha = 0;
        FlxTween.tween(prop, {alpha: exclusiveFull[i]}, FADE_IN_TIME, {ease: FlxEase.quadInOut});
      }
      else
      {
        // Al volver del retro, como en el original, aparecen de golpe.
        prop.alpha = exclusiveFull[i];
      }
    }

    // GradienteAdd: visible desde el inicio (0.6), sube a 0.7 en la fase 2 y se apaga en el retro. Cambia de golpe.
    if (lightAdd != null)
    {
      FlxTween.cancelTweensOf(lightAdd, ['alpha']);

      if (newPhase == 1) lightAdd.alpha = LIGHT_PHASE1_ALPHA;
      else if (newPhase == 2) lightAdd.alpha = LIGHT_PHASE2_ALPHA;
      else lightAdd.alpha = 0;
    }

    // glowrojo solo se ve en la parte retro.
    if (glowRojo != null)
    {
      FlxTween.cancelTweensOf(glowRojo, ['alpha']);
      glowRojo.alpha = (newPhase == 3) ? 1 : 0;
    }

    // Personajes.
    if (newPhase == 1)
    {
      // Fase 1: el motor (resetStage) ya restauró posición y foco de cámara; solo se devuelve el zIndex.
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

    // Reordenar por zIndex.
    refresh();
  }

  // Fase 1: fondonegro y fondo vuelven a los valores del JSON.
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

  // Fases 2 y 3: valores de defeat2 para fondonegro y fondo (en la fase 3, fondo se oculta y fondonegro no cambia).
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

      pulse.x = -1520;
      pulse.y = -202;
      pulse.scrollFactor.set(0.8, 0.8);
      pulse.blend = BlendMode.NORMAL;
      pulse.zIndex = 10;
      pulse.alpha = showFondo ? PULSE_REST_ALPHA : 0;
    }
  }

  // Solo zIndex y offset de cámara: la posición del personaje la define el JSON del stage y no se cambia.
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

  // Pulso por beat. Solo pulsan los elementos que ya son visibles (como en el original).
  function pulseOnBeat(beat:Int):Void
  {
    var flashing:Bool = flashingEnabled();

    if (PULSE_DEBUG_LOG) trace('[Void] pulso en el beat ' + beat + ' (fase ' + currentPhase + ', flashing: ' + flashing + ')');

    if (pulse != null && pulse.alpha > 0.01) pulseBackground(flashing);
    if (glowTop != null && glowTop.alpha > 0.01) pulseGlow(glowTop, flashing);
    if (glowBottom != null && glowBottom.alpha > 0.01) pulseGlow(glowBottom, flashing);
  }

  function pulseBackground(flashing:Bool):Void
  {
    // Se cancela por objeto y propiedad (como hace recordingStudio.hxc) en vez de guardar el tween.
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

  // Reintentar la canción: cancelar los tweens y volver a la fase 1.
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
      trace('[Void] volver a la fase 1 falló: ' + e);
    }
  }

  // Opción "luces parpadeantes" del jugador. Si no existe con este nombre en tu versión, asume que está activada.
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
        trace('[Void] Preferences.flashingLights no existe en esta versión, asumo flashing activado');
      }
    }

    return value != false;
  }
  // <<< FASES DEL STAGE "void" Y PULSO POR BEAT
}