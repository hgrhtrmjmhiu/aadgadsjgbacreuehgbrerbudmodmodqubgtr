import haxe.ds.StringMap;
import funkin.play.event.SongEvent;
import funkin.data.character.CharacterDataParser;
import funkin.play.character.BaseCharacter;
import funkin.play.character.CharacterType;
import funkin.play.PlayState;

class ChangeCharacterEventDefeat extends SongEvent
{
  var characterCache:StringMap<BaseCharacter> = new StringMap();
  var firstBF:String;
  var firstGF:String;
  var firstDad:String;
  var originalsCaptured:Bool = false;
  var cacheOwner:PlayState = null;

  public function new()
  {
    super('ChangeCharacterDefeat', {processOldEvents: true});
  }

  public override function getTitle():String
  {
    return 'Change Character [Defeat Port]';
  }

  function resetCacheIfNewPlayState():Void
  {
    if (cacheOwner == PlayState.instance) return;

    characterCache = new StringMap();
    originalsCaptured = false;
    cacheOwner = PlayState.instance;
  }

  override function handleEvent(data:SongEventData):Void
  {
    if (PlayState.instance == null || PlayState.instance.currentStage == null) return;

    resetCacheIfNewPlayState();

    captureOriginalsIfNeeded();

    var role:String = data.getString('char') ?? 'bf';
    var newChar:String = data.getString('newchar') ?? 'bf';
    var daX:Float = data.getFloat('x') ?? 0;
    var daY:Float = data.getFloat('y') ?? 0;

    try
    {
      changeCharacter(role, newChar, daX, daY);
    }
    catch (e:Dynamic)
    {
    }
  }

  function captureOriginalsIfNeeded():Void
  {
    if (originalsCaptured) return;
    if (PlayState.instance.currentChart == null) return;

    firstBF = PlayState.instance.currentChart.characters.player;
    firstGF = PlayState.instance.currentChart.characters.girlfriend;
    firstDad = PlayState.instance.currentChart.characters.opponent;
    originalsCaptured = true;
  }

  override function onSongRetry(event):Void
  {
    super.onSongRetry(event);

    resetCacheIfNewPlayState();

    if (!originalsCaptured) return;
    if (PlayState.instance == null || PlayState.instance.currentStage == null) return;

    try
    {
      if (firstBF != null) changeCharacter('bf', firstBF, 0, 0);
    }
    catch (e:Dynamic)
    {
    }

    try
    {
      if (firstGF != null) changeCharacter('gf', firstGF, 0, 0);
    }
    catch (e:Dynamic)
    {
    }

    try
    {
      if (firstDad != null) changeCharacter('dad', firstDad, 0, 0);
    }
    catch (e:Dynamic)
    {
    }
  }

  override function getEventSchema()
  {
    return [
      {
        name: 'char',
        title: 'Character',
        defaultValue: 'bf',
        type: 'enum',
        keys: [
          'Boyfriend' => 'bf',
          'Dad' => 'dad',
          'Girlfriend' => 'gf'
        ]
      },
      {
        name: 'newchar',
        title: 'New Character',
        defaultValue: 'bf',
        type: 'enum',
        keys: generateCharList()
      },
      {
        name: 'x',
        title: 'Offset X',
        defaultValue: 0,
        type: 'float'
      },
      {
        name: 'y',
        title: 'Offset Y',
        defaultValue: 0,
        type: 'float'
      }
    ];
  }

  function generateCharList():StringMap<String>
  {
    var charIDs:Array<String> = CharacterDataParser.listCharacterIds();
    var charMap:StringMap<String> = new StringMap();

    for (charID in charIDs)
    {
      var charData = CharacterDataParser.fetchCharacterData(charID);
      charMap.set(charData.name, charID);
    }
    return charMap;
  }

  function getOrFetchCharacter(charID:String):BaseCharacter
  {
    if (characterCache.exists(charID))
    {
      var cachedChar:BaseCharacter = characterCache.get(charID);

      cachedChar.revive();
      cachedChar.exists = true;

      if (PlayState.instance.currentStage.members.indexOf(cachedChar) == -1)
      {
        cachedChar.visible = false;
        cachedChar.active = false;
        cachedChar.alpha = 0.001;
        PlayState.instance.currentStage.add(cachedChar);
      }

      return cachedChar;
    }

    var char:BaseCharacter = CharacterDataParser.fetchCharacter(charID);
    if (char == null) return null;

    char.visible = false;
    char.active = false;
    char.alpha = 0.001;
    PlayState.instance.currentStage.add(char);

    characterCache.set(charID, char);
    return char;
  }

  function safeGetBaseScale(character:BaseCharacter, charID:String):Float
  {
    var scale:Float = 1;
    try
    {
      scale = character.getBaseScale();
    }
    catch (e:Dynamic)
    {
      scale = 1;
    }
    return scale;
  }

  function safeSetScale(character:BaseCharacter, scale:Float, charID:String):Void
  {
    try
    {
      character.setScale(scale);
    }
    catch (e:Dynamic)
    {
    }
  }

  function safeDance(character:BaseCharacter, charID:String):Void
  {
    try
    {
      character.dance(true);
    }
    catch (e:Dynamic)
    {
    }
  }

  function safeInitHealthIcon(character:BaseCharacter, charID:String, isOpponent:Bool):Void
  {
    try
    {
      character.initHealthIcon(isOpponent);
    }
    catch (e:Dynamic)
    {
    }
  }

  function finalizeCamera(character:BaseCharacter, stageCharData):Void
  {
    try
    {
      character.originalPosition.set(character.x, character.y);
      character.resetCameraFocusPoint();

      if (stageCharData != null && stageCharData.cameraOffsets != null)
      {
        character.cameraFocusPoint.x += stageCharData.cameraOffsets[0];
        character.cameraFocusPoint.y += stageCharData.cameraOffsets[1];
      }
    }
    catch (e:Dynamic)
    {
    }
  }

  function changeCharacter(role:String, newChar:String, daX:Float = 0, daY:Float = 0):Void
  {
    var newCharacter:BaseCharacter = getOrFetchCharacter(newChar);
    if (newCharacter == null) return;

    var charactersData = PlayState.instance.currentStage._data.characters;

    switch (role)
    {
      case 'bf':
        var oldBF = PlayState.instance.currentStage.getBoyfriend();
        if (oldBF != null && oldBF != newCharacter)
        {
          oldBF.alpha = 0.001;
          oldBF.visible = false;
          oldBF.active = false;
        }

        var stageScale:Float = 1;
        if (charactersData != null && charactersData.bf != null && charactersData.bf.scale != null)
        {
          stageScale = charactersData.bf.scale;
        }

        var basePos = PlayState.instance.currentStage.getBoyfriendPosition();
        newCharacter.x = basePos.x - newCharacter.characterOrigin.x + daX;
        newCharacter.y = basePos.y - newCharacter.characterOrigin.y + daY;
        newCharacter.resetCameraFocusPoint();

        if (charactersData != null && charactersData.bf != null && charactersData.bf.cameraOffsets != null)
        {
          newCharacter.cameraFocusPoint.x += charactersData.bf.cameraOffsets[0];
          newCharacter.cameraFocusPoint.y += charactersData.bf.cameraOffsets[1];
        }

        newCharacter.flipX = !newCharacter.getDataFlipX();
        safeSetScale(newCharacter, safeGetBaseScale(newCharacter, newChar) * stageScale, newChar);
        if (oldBF != null) newCharacter.zIndex = oldBF.zIndex;
        newCharacter.visible = true;
        newCharacter.alpha = 1;
        newCharacter.active = true;
        newCharacter.characterType = CharacterType.BF;
        safeDance(newCharacter, newChar);
        finalizeCamera(newCharacter, charactersData != null ? charactersData.bf : null);
        PlayState.instance.currentStage.characters.set('bf', newCharacter);
        safeInitHealthIcon(newCharacter, newChar, false);

      case 'dad':
        var oldDad = PlayState.instance.currentStage.getDad();
        if (oldDad != null && oldDad != newCharacter)
        {
          oldDad.alpha = 0.001;
          oldDad.visible = false;
          oldDad.active = false;
        }

        var stageScale:Float = 1;
        if (charactersData != null && charactersData.dad != null && charactersData.dad.scale != null)
        {
          stageScale = charactersData.dad.scale;
        }

        var basePos = PlayState.instance.currentStage.getDadPosition();
        newCharacter.x = basePos.x - newCharacter.characterOrigin.x + daX;
        newCharacter.y = basePos.y - newCharacter.characterOrigin.y + daY;
        newCharacter.resetCameraFocusPoint();

        if (charactersData != null && charactersData.dad != null && charactersData.dad.cameraOffsets != null)
        {
          newCharacter.cameraFocusPoint.x += charactersData.dad.cameraOffsets[0];
          newCharacter.cameraFocusPoint.y += charactersData.dad.cameraOffsets[1];
        }

        newCharacter.flipX = newCharacter.getDataFlipX();
        safeSetScale(newCharacter, safeGetBaseScale(newCharacter, newChar) * stageScale, newChar);
        if (oldDad != null) newCharacter.zIndex = oldDad.zIndex;
        newCharacter.visible = true;
        newCharacter.alpha = 1;
        newCharacter.active = true;
        newCharacter.characterType = CharacterType.DAD;
        safeDance(newCharacter, newChar);
        finalizeCamera(newCharacter, charactersData != null ? charactersData.dad : null);
        PlayState.instance.currentStage.characters.set('dad', newCharacter);
        safeInitHealthIcon(newCharacter, newChar, true);

      case 'gf':
        var oldGF = PlayState.instance.currentStage.getGirlfriend();
        if (oldGF != null && oldGF != newCharacter)
        {
          oldGF.alpha = 0.001;
          oldGF.visible = false;
          oldGF.active = false;
        }

        var stageScale:Float = 1;
        if (charactersData != null && charactersData.gf != null && charactersData.gf.scale != null)
        {
          stageScale = charactersData.gf.scale;
        }

        var basePos = PlayState.instance.currentStage.getGirlfriendPosition();
        newCharacter.x = basePos.x - newCharacter.characterOrigin.x + daX;
        newCharacter.y = basePos.y - newCharacter.characterOrigin.y + daY;
        newCharacter.resetCameraFocusPoint();

        if (charactersData != null && charactersData.gf != null && charactersData.gf.cameraOffsets != null)
        {
          newCharacter.cameraFocusPoint.x += charactersData.gf.cameraOffsets[0];
          newCharacter.cameraFocusPoint.y += charactersData.gf.cameraOffsets[1];
        }

        newCharacter.flipX = newCharacter.getDataFlipX();
        safeSetScale(newCharacter, safeGetBaseScale(newCharacter, newChar) * stageScale, newChar);
        if (oldGF != null) newCharacter.zIndex = oldGF.zIndex;
        newCharacter.visible = true;
        newCharacter.alpha = 1;
        newCharacter.active = true;
        newCharacter.characterType = CharacterType.GF;
        safeDance(newCharacter, newChar);
        finalizeCamera(newCharacter, charactersData != null ? charactersData.gf : null);
        PlayState.instance.currentStage.characters.set('gf', newCharacter);
    }

    PlayState.instance.currentStage.refresh();
  }
}