local EVIL_EDITION = 'e_purpleaiden_evil'
local LAUGH_SOUND = 'purpleaiden_laugh'
local EVIL_PROGRESS_MAX = 4
local EVIL_DESTROY_CHANCE = 2
local LAUGH_PITCH_STEP = 0.08
local LAUGH_MIN_PITCH = 0.45

local registered_sounds = {}

local function sound_file_exists(filename)
    if not (NFS and NFS.getInfo and SMODS and SMODS.current_mod and SMODS.current_mod.path) then
        return false
    end

    return NFS.getInfo(SMODS.current_mod.path .. 'assets/sounds/' .. filename) ~= nil
end

local function register_sound(key, filename)
    if sound_file_exists(filename) then
        SMODS.Sound {
            key = 'purpleaiden_' .. key,
            path = filename,
            prefix_config = { key = false }
        }
        registered_sounds['purpleaiden_' .. key] = true
    end
end

local function play_registered_sound(sound_key, pitch, volume)
    if registered_sounds[sound_key] then
        play_sound(sound_key, pitch or 1, volume or 0.7)
    end
end

local function get_laugh_count()
    if not (G and G.GAME) then
        return 0
    end

    G.GAME.purpleaiden_laugh_count = G.GAME.purpleaiden_laugh_count or 0
    return G.GAME.purpleaiden_laugh_count
end

local function play_evil_laugh()
    local laugh_count = get_laugh_count()
    local pitch = math.max(LAUGH_MIN_PITCH, 1 - (laugh_count * LAUGH_PITCH_STEP))

    play_registered_sound(LAUGH_SOUND, pitch, 0.8)

    if G and G.GAME then
        G.GAME.purpleaiden_laugh_count = laugh_count + 1
    end
end

local function is_evil_card(card)
    return card
        and card.edition
        and card.edition.key == EVIL_EDITION
end

local function make_wild_card(card)
    if card and G and G.P_CENTERS and G.P_CENTERS.m_wild then
        card:set_ability(G.P_CENTERS.m_wild, nil, false)
    end
end

local function init_evil_card(card)
    if not (card and card.ability) then
        return
    end

    card.ability.purpleaiden_evil_progress = card.ability.purpleaiden_evil_progress or 0
    if card.ability.purpleaiden_evil_destroy_ready == nil then
        card.ability.purpleaiden_evil_destroy_ready =
            card.ability.purpleaiden_evil_progress >= EVIL_PROGRESS_MAX
    end
end

-- FIX #1: Added nil guard after init_evil_card, since init_evil_card returns
-- early when card.ability is nil, which would then cause a crash on the
-- next line if we blindly indexed card.ability.
local function get_evil_progress(card)
    init_evil_card(card)
    if not (card and card.ability) then
        return 0
    end
    return card.ability.purpleaiden_evil_progress or 0
end

local function get_evil_status(card)
    local progress = math.min(get_evil_progress(card), EVIL_PROGRESS_MAX)
    local purple = math.floor((progress / EVIL_PROGRESS_MAX) * 100)
    local turns_left = math.max(EVIL_PROGRESS_MAX - progress, 0)

    return purple, turns_left
end

local function set_evil_progress(card, progress)
    if not (card and card.ability) then
        return
    end

    card.ability.purpleaiden_evil_progress = math.min(progress, EVIL_PROGRESS_MAX)
end

local function grow_evil_card(card)
    local progress = get_evil_progress(card)

    if progress >= EVIL_PROGRESS_MAX then
        card.ability.purpleaiden_evil_destroy_ready = true
        return
    end

    set_evil_progress(card, progress + 1)
    card.ability.purpleaiden_evil_destroy_ready = false
end

local function eligible_playing_cards()
    local cards = {}

    if not (G and G.playing_cards) then
        return cards
    end

    for _, card in ipairs(G.playing_cards) do
        -- FIX #2: Added nil guard on card.ability before accessing card.ability.eternal.
        -- Without this, any card whose .ability table is nil causes a crash here.
        if card
            and not is_evil_card(card)
            and not card.edition
            and not (card.ability and card.ability.eternal)
        then
            cards[#cards + 1] = card
        end
    end

    return cards
end

local function apply_evil_edition(card)
    if not card then
        return false
    end

    make_wild_card(card)
    card:set_edition(EVIL_EDITION, true, false, false)
    init_evil_card(card)
    play_evil_laugh()

    if card.juice_up then
        card:juice_up(0.7, 0.7)
    end

    return true
end

local function pick_random_eligible_card(seed)
    local cards = eligible_playing_cards()

    if #cards <= 0 then
        return nil
    end

    return pseudorandom_element(cards, pseudoseed(seed))
end

register_sound('laugh', 'laugh.mp3')

-- FIX #3: Register the custom evil shader BEFORE the edition that references
-- it. The shader key + filename (without extension) must match per the SMODS
-- docs. SMODS will prefix the key with the mod prefix ('purpleaiden'), making
-- the final resolved key 'purpleaiden_evil'.
-- send_vars supplies the two custom uniforms declared in evil.fs:
--   evil        (vec2)  – dummy guard uniform, keep at {0,0}
--   evil_amount (float) – drives the purple tint intensity [0.0..1.0]
SMODS.Shader {
    key = 'purpleaiden_evil',
    path = 'evil.fs',
    prefix_config = { key = false },
    send_vars = function(sprite, card)
        local evil_amount = 0
        if card and card.ability then
            local progress = card.ability.purpleaiden_evil_progress or 0
            evil_amount = math.min(progress, EVIL_PROGRESS_MAX) / EVIL_PROGRESS_MAX
        end
        return {
            evil = { 0, 0 },
            evil_amount = evil_amount
        }
    end
}

SMODS.Atlas {
    key = 'purpleaiden_Jokers',
    path = 'purpleaiden_Jokers.png',
    px = 71,
    py = 95,
    prefix_config = { key = false }
}

SMODS.Edition {
    key = EVIL_EDITION,
    prefix_config = { key = false, shader = false },
    -- FIX #4: Was 'negative' (the built-in shader). Changed to 'purpleaiden_evil'
    -- so the custom evil.fs shader is actually used. SMODS resolves the prefixed
    -- key 'purpleaiden_evil' to the SMODS.Shader we registered above.
    shader = 'purpleaiden_evil',
    config = {
        extra = {
            mult = 20,
            retrigger_odds = 8
        }
    },
    loc_txt = {
        name = 'Evil Edition',
        label = 'Evil',
        text = {
            '{C:mult}+#1#{} Mult',
            '{C:green}#2# in #3#{} chance to retrigger',
            'also becomes a {C:attention}Wild Card{}',
            'becomes more {C:purple}purple{} when scored',
            '{C:green}1 in #4#{} chance to destroy',
            'once fully purple',
            '{C:purple}#5#%{} purple',
            '{C:inactive}#6# scored turns until fully purple{}'
        }
    },
    loc_vars = function(self, info_queue, card)
        local numerator, denominator = SMODS.get_probability_vars(
            card or self,
            1,
            self.config.extra.retrigger_odds,
            'purpleaiden_evil_retrigger'
        )
        local purple, turns_left = get_evil_status(card)

        return {
            vars = {
                self.config.extra.mult,
                numerator,
                denominator,
                EVIL_DESTROY_CHANCE,
                purple,
                turns_left
            }
        }
    end,
    on_apply = function(card)
        make_wild_card(card)
        init_evil_card(card)
    end,
    on_load = function(card)
        init_evil_card(card)
    end,
    calculate = function(self, card, context)
        if context.cardarea == G.play and context.main_scoring then
            grow_evil_card(card)
            local purple, turns_left = get_evil_status(card)
            local turns_text = turns_left == 1 and '1 scored turn' or (turns_left .. ' scored turns')

            card_eval_status_text(card, 'extra', nil, nil, nil, {
                message = purple .. '% purple, ' .. turns_text .. ' left',
                colour = G.C.PURPLE
            })

            return {
                mult = self.config.extra.mult,
                message = '+' .. self.config.extra.mult .. ' Mult',
                colour = G.C.MULT
            }
        end

        if context.cardarea == G.play
            and context.repetition
            and SMODS.pseudorandom_probability(
                card,
                'purpleaiden_evil_retrigger',
                1,
                self.config.extra.retrigger_odds,
                'purpleaiden_evil_retrigger'
            )
        then
            return {
                repetitions = 1,
                message = 'Again!',
                colour = G.C.PURPLE
            }
        end
    end,
    in_shop = false,
    weight = 0,
    badge_colour = HEX('6B21A8'),
    -- FIX #5: Was G.C.WHITE, which is evaluated at mod load time before G.C
    -- is fully initialised, causing a nil-index crash. HEX() is safe to call
    -- at load time because it doesn't depend on G.
    text_colour = HEX('FFFFFF')
}

BalatroAidenMod.add_calculate(function(self, context)
    if context.destroy_card
        and context.cardarea == G.play
        and is_evil_card(context.destroy_card)
        -- FIX #6: get_evil_progress now nil-guards internally (see FIX #1), so
        -- this call no longer crashes when context.destroy_card lacks .ability.
        and get_evil_progress(context.destroy_card) >= EVIL_PROGRESS_MAX
        and context.destroy_card.ability
        and context.destroy_card.ability.purpleaiden_evil_destroy_ready
        and pseudorandom('purpleaiden_evil_destroy') < 1 / EVIL_DESTROY_CHANCE
    then
        return {
            remove = true,
            message = 'Destroyed!',
            colour = G.C.PURPLE
        }
    end
end)

SMODS.Joker {
    key = 'j_purpleaiden_purple_aiden',
    prefix_config = { key = false, atlas = false },
    loc_txt = {
        name = 'Purple Aiden',
        text = {
            'the evilest Aiden.',
            '{C:green}#1# in #2#{} chance to transform',
            'each card in your {C:attention}played hand{}',
            'with {C:dark_edition}Evil Edition{}'
        }
    },
    config = {
        extra = {
            odds = 10
        }
    },
    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS[EVIL_EDITION]

        local odds = self.config.extra.odds
        if card and card.ability and card.ability.extra and card.ability.extra.odds then
            odds = card.ability.extra.odds
        end

        local numerator, denominator = SMODS.get_probability_vars(
            card or self,
            1,
            odds,
            'purpleaiden_apply_evil'
        )

        return {
            vars = { numerator, denominator }
        }
    end,
    atlas = 'purpleaiden_Jokers',
    rarity = 2,
    cost = 7,
    unlocked = true,
    discovered = true,
    blueprint_compat = true,
    eternal_compat = true,
    perishable_compat = true,
    pos = { x = 0, y = 0 },
    calculate = function(self, card, context)
        if not (context.before and context.scoring_hand) then
            return
        end

        -- Roll once per card in the scoring hand so each card gets
        -- its own independent 1 in N chance, rather than one roll per hand.
        local triggered = false
        for _, played_card in ipairs(context.scoring_hand) do
            if not is_evil_card(played_card)
                and not played_card.edition
                and not (played_card.ability and played_card.ability.eternal)
                and SMODS.pseudorandom_probability(
                    card,
                    'purpleaiden_apply_evil',
                    1,
                    card.ability.extra.odds,
                    'purpleaiden_apply_evil'
                )
            then
                if apply_evil_edition(played_card) then
                    triggered = true
                end
            end
        end

        if triggered then
            return {
                message = 'Evil!',
                colour = G.C.PURPLE
            }
        end
    end
}
