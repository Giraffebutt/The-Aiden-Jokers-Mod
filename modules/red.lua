local RED_AIDEN_KEY = 'j_redaiden_red_aiden'
local RED_AIDEN_SHADER = 'redaiden_fire'
local COMEBACK_RATIO = 0.5
local REWARD_DOLLARS = 5
local SHADER_ALPHA = 0.42
local SHADER_FADE_IN = 0.35
local SHADER_FADE_OUT = 1.0

local function real_time()
    return G and G.TIMERS and G.TIMERS.REAL or 0
end

local function get_extra(card)
    card.ability.extra = card.ability.extra or {}
    local extra = card.ability.extra

    extra.comeback_ratio = extra.comeback_ratio or COMEBACK_RATIO
    extra.reward_dollars = extra.reward_dollars or REWARD_DOLLARS
    extra.shader_alpha = extra.shader_alpha or SHADER_ALPHA
    extra.shader_active = extra.shader_active or false
    extra.shader_started_at = extra.shader_started_at or 0
    extra.shader_fade_out_at = extra.shader_fade_out_at or nil

    return extra
end

local function is_red_aiden(card)
    local center = card and card.config and card.config.center

    return center
        and (
            center.key == RED_AIDEN_KEY
            or center.original_key == 'red_aiden'
        )
end

local function is_last_hand()
    return G
        and G.GAME
        and G.GAME.current_round
        and G.GAME.current_round.hands_left == 0
end

local function big_value(value)
    if type(to_big) == 'function' then
        return to_big(value or 0)
    end

    return value or 0
end

local function current_hand_score()
    if SMODS and type(SMODS.calculate_round_score) == 'function' then
        return SMODS.calculate_round_score()
    end

    return (hand_chips or 0) * (mult or 0)
end

local function is_far_behind(card)
    if not (G and G.GAME and G.GAME.blind) then
        return false
    end

    local blind_chips = G.GAME.blind.chips or 0
    local chips = G.GAME.chips or 0
    local ratio = get_extra(card).comeback_ratio

    if type(to_big) == 'function' then
        return big_value(chips) < big_value(blind_chips) * ratio
    end

    if blind_chips <= 0 then
        return false
    end

    return chips < blind_chips * ratio
end

local function comeback_should_activate(card)
    return is_last_hand() and is_far_behind(card)
end

local function current_flame_score()
    if SMODS and type(SMODS.calculate_round_score) == 'function' then
        local score = SMODS.calculate_round_score()

        if score and score ~= 0 then
            return score
        end

        return SMODS.calculate_round_score(true)
    end

    local current_hand = G
        and G.GAME
        and G.GAME.current_round
        and G.GAME.current_round.current_hand

    if current_hand and type(current_hand.chips) == 'number' and type(current_hand.mult) == 'number' then
        return current_hand.chips * current_hand.mult
    end

    return current_hand_score()
end

local function hand_triggers_score_flames(use_last_hand_flag)
    if not (G and G.GAME and G.GAME.blind) then
        return false
    end

    if use_last_hand_flag and SMODS and SMODS.last_hand_oneshot ~= nil then
        return SMODS.last_hand_oneshot
    end

    local required_score = G.GAME.blind.chips or 0
    local earned_score = current_flame_score()

    if type(to_big) == 'function' then
        return big_value(required_score) > big_value(0)
            and big_value(earned_score) >= big_value(required_score)
    end

    if required_score <= 0 then
        return false
    end

    return earned_score >= required_score
end

local function blind_will_be_cleared()
    if not (G and G.GAME and G.GAME.blind) then
        return false
    end

    local required_score = G.GAME.blind.chips or 0
    local total_after_hand = big_value(G.GAME.chips or 0) + big_value(current_hand_score())

    return big_value(required_score) > big_value(0)
        and total_after_hand >= big_value(required_score)
end

local function mark_fire_active(card)
    local extra = get_extra(card)

    if not extra.shader_active or extra.shader_fade_out_at then
        extra.shader_started_at = real_time()
    end

    extra.shader_active = true
    extra.shader_fade_out_at = nil
end

local function fade_fire_out(card)
    local extra = get_extra(card)

    if extra.shader_active and not extra.shader_fade_out_at then
        extra.shader_fade_out_at = real_time()
    end
end

local function fire_alpha(card)
    local extra = card and card.ability and card.ability.extra

    if not (extra and extra.shader_active) then
        return 0
    end

    local now = real_time()
    local fade_in = math.min(1, math.max(0, (now - (extra.shader_started_at or now)) / SHADER_FADE_IN))
    local fade_out = 1

    if extra.shader_fade_out_at then
        fade_out = 1 - math.max(0, (now - extra.shader_fade_out_at) / SHADER_FADE_OUT)

        if fade_out <= 0 then
            extra.shader_active = false
            extra.shader_fade_out_at = nil
            return 0
        end
    end

    return (extra.shader_alpha or SHADER_ALPHA) * fade_in * math.min(1, fade_out)
end

local function activation_sound_key(kind)
    if not (G and G.GAME and G.GAME.current_round) then
        return tostring(kind or 'activate') .. ':none'
    end

    local blind = G.GAME.blind or G.GAME.round_resets and G.GAME.round_resets.blind
    local blind_key = blind and (blind.key or blind.name or blind.config and blind.config.blind and blind.config.blind.key) or 'blind'

    return table.concat({
        tostring(kind or 'activate'),
        tostring(G.GAME.round_resets and G.GAME.round_resets.ante or 0),
        tostring(blind_key),
        tostring(G.GAME.current_round.hands_played or 0),
        tostring(G.GAME.current_round.hands_left or 0)
    }, ':')
end

local function play_activation_sound(card, kind)
    local extra = get_extra(card)
    local sound_key = activation_sound_key(kind)

    if extra.last_sound_key ~= sound_key then
        extra.last_sound_key = sound_key

        if type(play_sound) == 'function' then
            play_sound('redaiden_raaah', 1, 0.7)
        end
    end
end

local function activate_red_aiden(card, kind)
    mark_fire_active(card)
    play_activation_sound(card, kind)
end

local function can_reward_this_hand(card, use_last_hand_flag)
    local extra = get_extra(card)
    local reward_key = activation_sound_key('reward')

    if extra.last_reward_key == reward_key then
        return false
    end

    if not hand_triggers_score_flames(use_last_hand_flag) then
        return false
    end

    extra.last_reward_key = reward_key
    return true
end

local function reward_red_aiden(card, effect_card)
    local extra = get_extra(card)

    mark_fire_active(card)
    play_activation_sound(card, 'reward')

    if G and G.GAME and type(ease_dollars) == 'function' then
        ease_dollars(extra.reward_dollars)
    elseif G and G.GAME then
        G.GAME.dollars = (G.GAME.dollars or 0) + extra.reward_dollars
    end

    return {
        message = '+$' .. tostring(extra.reward_dollars),
        colour = G.C.MONEY,
        card = effect_card or card
    }
end

local function fire_is_active(card)
    return fire_alpha(card) > 0
end

SMODS.Shader {
    key = RED_AIDEN_SHADER,
    path = 'fire.fs',
    prefix_config = { key = false }
}

SMODS.Sound {
    key = 'redaiden_raaah',
    path = 'raaah.ogg',
    prefix_config = { key = false }
}

SMODS.DrawStep {
    key = 'redaiden_fire_overlay',
    prefix_config = { key = false },
    order = 21,
    func = function(card, layer)
        if not (is_red_aiden(card) and fire_is_active(card)) then
            return
        end

        local shader_send = {
            real_time(),
            fire_alpha(card)
        }

        if card.children and card.children.center then
            card.children.center:draw_shader(RED_AIDEN_SHADER, nil, shader_send)
        end

        if card.children
            and card.children.front
            and (card.ability.delayed or not card:should_hide_front())
        then
            card.children.front:draw_shader(RED_AIDEN_SHADER, nil, shader_send)
        end
    end,
    conditions = { vortex = false, facing = 'front' }
}

SMODS.Atlas {
    key = 'redaiden_Jokers',
    path = 'redaiden_Jokers.png',
    px = 71,
    py = 95,
    prefix_config = { key = false }
}

SMODS.Joker {
    key = RED_AIDEN_KEY,
    prefix_config = { key = false, atlas = false },
    loc_txt = {
        name = 'Red Aiden',
        text = {
            'If you have {C:attention}1{} hand left,',
            'and are below {C:attention}#1#%{} of required score,',
            '{C:attention}scoring cards{} retrigger once.',
            'If the hand ignites score flames,',
            'gain {C:money}$#2#{}'
        }
    },
    atlas = 'redaiden_Jokers',
    pos = { x = 0, y = 0 },
    rarity = 2,
    cost = 6,
    unlocked = true,
    discovered = true,
    blueprint_compat = true,
    eternal_compat = true,
    perishable_compat = true,
    config = {
        extra = {
            comeback_ratio = COMEBACK_RATIO,
            reward_dollars = REWARD_DOLLARS,
            shader_alpha = SHADER_ALPHA,
            shader_active = false,
            shader_started_at = 0,
            shader_fade_out_at = nil
        }
    },
    loc_vars = function(self, info_queue, card)
        local extra = card and get_extra(card) or self.config.extra

        return {
            vars = {
                math.floor((extra.comeback_ratio or COMEBACK_RATIO) * 100),
                extra.reward_dollars or REWARD_DOLLARS
            }
        }
    end,
    calculate = function(self, card, context)
        if context and context.end_of_round then
            fade_fire_out(card)
            return nil
        end

        if context and context.before and comeback_should_activate(card) then
            activate_red_aiden(card, 'comeback')

            return {
                message = 'Comeback!',
                colour = G.C.RED,
                card = context.blueprint_card or card
            }
        end

        -- Retriggers scoring cards once
        if context
            and context.repetition
            and context.cardarea == G.play
            and context.other_card
            and comeback_should_activate(card)
        then
            mark_fire_active(card)

            return {
                message = localize('k_again_ex'),
                repetitions = 1,
                card = context.blueprint_card or card
            }
        end

        if context and context.final_scoring_step and can_reward_this_hand(card) then
            return reward_red_aiden(card, context.blueprint_card or card)
        end

        if context and context.after and can_reward_this_hand(card, true) then
            return reward_red_aiden(card, context.blueprint_card or card)
        end

        if context and context.after and blind_will_be_cleared() then
            fade_fire_out(card)
        end

        return nil
    end
}
