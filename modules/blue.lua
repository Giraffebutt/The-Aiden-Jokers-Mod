local LOW_SCORE_RATIO = 0.15
local PITY_XMULT = 2
local PITY_DOLLARS = 3
local SADNESS_MAX = 5
local FINAL_DOLLARS = 10

local function get_extra(card)
    card.ability.extra = card.ability.extra or {}
    local extra = card.ability.extra

    extra.pity_xmult = extra.pity_xmult or PITY_XMULT
    extra.pity_dollars = extra.pity_dollars or PITY_DOLLARS
    extra.sadness = extra.sadness or 0
    extra.sadness_max = extra.sadness_max or SADNESS_MAX
    extra.final_dollars = extra.final_dollars or FINAL_DOLLARS
    extra.low_score_ratio = extra.low_score_ratio or LOW_SCORE_RATIO

    return extra
end

local function current_score()
    return (hand_chips or 0) * (mult or 0)
end

local function score_is_low(card)
    if not (G and G.GAME and G.GAME.blind) then
        return false
    end

    local extra = get_extra(card)
    local blind_chips = G.GAME.blind.chips or 0
    local score = current_score()

    if type(to_big) == 'function' then
        local big_blind = to_big(blind_chips)
        if big_blind <= to_big(0) then
            return false
        end

        return to_big(score) <= big_blind * extra.low_score_ratio
    end

    if blind_chips <= 0 then
        return false
    end

    return score <= blind_chips * extra.low_score_ratio
end

local function should_award_pity(card, context)
    if not (context and context.joker_main) then
        return false
    end

    return context.scoring_name == 'High Card' or score_is_low(card)
end

local function destroy_blue_aiden(card)
    if not (card and card.start_dissolve) then
        return
    end
    if card.getting_sliced or card.removed then
        return
    end

    card.getting_sliced = true
    G.E_MANAGER:add_event(Event({
        trigger = 'after',
        delay = 0.15,
        func = function()
            card:start_dissolve({ G.C.BLUE }, nil, 1.6)
            return true
        end
    }))
end

local function pity_effect(card, context)
    local extra = get_extra(card)
    local real_card = context.blueprint_card or card
    local reached_max = false

    if not context.blueprint and not context.retrigger_joker then
        extra.sadness = extra.sadness + 1
        reached_max = extra.sadness >= extra.sadness_max
    end

    local effect = {
        message = 'Pity!',
        colour = G.C.BLUE,
        Xmult_mod = extra.pity_xmult,
        dollars = extra.pity_dollars,
        card = real_card,
        func = function()
            play_sound('blueaiden_crying', 1, 0.7)
        end
    }

    if reached_max then
        effect.extra = {
            message = 'Too Sad!',
            colour = G.C.MONEY,
            dollars = extra.final_dollars,
            card = real_card,
            func = function()
                destroy_blue_aiden(card)
            end
        }
    end

    return effect
end

SMODS.Atlas {
    key = 'blueaiden_Jokers',
    path = 'blueaiden_Jokers.png',
    px = 71,
    py = 95,
    prefix_config = { key = false }
}

SMODS.Sound {
    key = 'blueaiden_crying',
    path = 'crying.ogg',
    prefix_config = { key = false }
}

SMODS.Joker {
    key = 'j_blueaiden_blue_aiden',
    prefix_config = { key = false, atlas = false },
    loc_txt = {
        name = 'Blue Aiden',
        text = {
            'Played {C:attention}High Card{} hands',
            'or hands scoring below {C:attention}#5#%{}',
            'of the blind gain {X:mult,C:white}X#1#{} Mult',
            'and {C:money}$#2#{}',
            '{C:inactive}Sadness: #3#/#4#{}',
            '{C:inactive}At max sadness, destroys itself',
            '{C:inactive}and gives {C:money}$#6#{C:inactive}{}'
        }
    },
    atlas = 'blueaiden_Jokers',
    pos = { x = 0, y = 0 },
    rarity = 2,
    cost = 6,
    unlocked = true,
    discovered = true,
    blueprint_compat = true,
    eternal_compat = false,
    perishable_compat = true,
    config = {
        extra = {
            pity_xmult = PITY_XMULT,
            pity_dollars = PITY_DOLLARS,
            sadness = 0,
            sadness_max = SADNESS_MAX,
            final_dollars = FINAL_DOLLARS,
            low_score_ratio = LOW_SCORE_RATIO
        }
    },
    loc_vars = function(self, info_queue, card)
        local extra = card and get_extra(card) or self.config.extra

        return {
            vars = {
                extra.pity_xmult,
                extra.pity_dollars,
                extra.sadness,
                extra.sadness_max,
                math.floor((extra.low_score_ratio or LOW_SCORE_RATIO) * 100),
                extra.final_dollars
            }
        }
    end,
    calculate = function(self, card, context)
        if should_award_pity(card, context) then
            return pity_effect(card, context)
        end

        return nil
    end
}
