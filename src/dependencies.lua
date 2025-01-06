-- Core

_G.KeyMappings  = require 'keymap'
_G.AIController = require 'ai.aicontroller'
_G.SoundManager = require 'sound.soundmanager'
-- Lib
_G.Gui          = require 'lib.gui'
_G.Class        = require 'lib.class'
_G.table        = require 'lib.table'
_G.Anim8        = require 'lib.anim8'
-- Entities
_G.Fighter = require 'entities.fighter'
-- States
_G.StateMachine    = require 'states.statemachine'
_G.Menu            = require 'states.menu'
_G.Loading         = require 'states.loading'
_G.Game            = require 'states.game'
_G.CharacterSelect = require 'states.characterselect'
_G.Settings        = require 'states.settings'
_G.Controls        = require 'states.controls'
