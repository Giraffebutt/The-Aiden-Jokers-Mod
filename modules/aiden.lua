local AUTISTIC_ENHANCEMENT = 'm_aidenjoker_autistic'
local AIDEN_JOKER = 'j_aidenjoker_aiden'
local OH_MY_GOD_SOUND = 'aidenjoker_ohmygod'
local HOLY_SOUND = 'aidenjoker_holy'
local APPEAR_SOUND = 'aidenjoker_appear'
local FLUSH_SHOP_BOOST_DENOMINATOR = 4

local RARE_HANDS = {
    ['Royal Flush'] = true,
    ['Straight Flush'] = true,
    ['Four of a Kind'] = true,
    ['Full House'] = true
}

local FLUSH_HANDS = {
    ['Flush'] = true,
    ['Straight Flush'] = true,
    ['Royal Flush'] = true,
    ['Flush House'] = true,
    ['Flush Five'] = true
}

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
            key = 'aidenjoker_' .. key,
            path = filename,
            prefix_config = { key = false }
        }
        registered_sounds['aidenjoker_' .. key] = true
    end
end

local function play_registered_sound(sound_key, pitch, volume)
    if registered_sounds[sound_key] then
        play_sound(sound_key, pitch or 1, volume or 0.7)
    end
end

local function card_is_aiden_joker(card)
    return card
        and card.config
        and card.config.center
        and card.config.center.key == AIDEN_JOKER
end

local function area_has_aiden_joker(area)
    if not (area and area.cards) then
        return false
    end

    for _, card in ipairs(area.cards) do
        if card_is_aiden_joker(card) then
            return true
        end
    end

    return false
end

local function aiden_joker_exists()
    return area_has_aiden_joker(G and G.jokers)
        or area_has_aiden_joker(G and G.shop_jokers)
end

local function is_rare_hand(context)
    if context.scoring_name and RARE_HANDS[context.scoring_name] then
        return true
    end

    if not context.poker_hands then
        return false
    end

    for hand_name in pairs(RARE_HANDS) do
        if context.poker_hands[hand_name] and next(context.poker_hands[hand_name]) then
            return true
        end
    end

    return false
end

local function is_flush_hand(context)
    if context.scoring_name and FLUSH_HANDS[context.scoring_name] then
        return true
    end

    return context.poker_hands
        and context.poker_hands['Flush']
        and next(context.poker_hands['Flush']) ~= nil
end

local function get_flush_shop_boost()
    if not (G and G.GAME) then
        return 0
    end

    G.GAME.aidenjoker_flush_shop_boost = G.GAME.aidenjoker_flush_shop_boost or 0
    return G.GAME.aidenjoker_flush_shop_boost
end

local function add_flush_shop_boost()
    if not (G and G.GAME) then
        return
    end

    G.GAME.aidenjoker_flush_shop_boost = math.min(
        get_flush_shop_boost() + 1,
        FLUSH_SHOP_BOOST_DENOMINATOR
    )
end

local function reset_flush_shop_boost()
    if G and G.GAME then
        G.GAME.aidenjoker_flush_shop_boost = 0
    end
end

local function roll_flush_shop_boost()
    local boost = get_flush_shop_boost()

    if boost <= 0 then
        return false
    end

    local roll = pseudorandom and pseudorandom('aidenjoker_flush_shop') or math.random()
    return roll < boost / FLUSH_SHOP_BOOST_DENOMINATOR
end

local function card_has_autistic_enhancement(card)
    return card
        and card.config
        and card.config.center
        and card.config.center.key == AUTISTIC_ENHANCEMENT
end

local function juice_aiden_jokers()
    if not (G and G.jokers and G.jokers.cards) then
        return
    end

    for _, joker in ipairs(G.jokers.cards) do
        if joker.config and joker.config.center and joker.config.center.key == AIDEN_JOKER then
            joker:juice_up(0.7, 0.7)
        end
    end
end

local function show_autistic_transform(card, delay)
    if card_eval_status_text then
        card_eval_status_text(card, 'extra', nil, nil, nil, {
            message = 'Autistic!',
            colour = G.C.FILTER
        })
    end

    if G and G.E_MANAGER and Event then
        G.E_MANAGER:add_event(Event {
            trigger = 'after',
            delay = delay or 0,
            func = function()
                if card then
                    if card.start_materialize then
                        card:start_materialize({ G.C.FILTER }, nil, 0.7)
                    elseif card.juice_up then
                        card:juice_up(0.8, 0.8)
                    end
                end

                return true
            end
        })
    elseif card then
        if card.start_materialize then
            card:start_materialize({ G.C.FILTER }, nil, 0.7)
        elseif card.juice_up then
            card:juice_up(0.8, 0.8)
        end
    end
end

local function apply_autistic_enhancement(card, delay)
    if card_has_autistic_enhancement(card) then
        return false
    end

    card:set_ability(G.P_CENTERS[AUTISTIC_ENHANCEMENT], nil, true)
    show_autistic_transform(card, delay)
    return true
end

register_sound('ohmygod', 'ohmygod.ogg')
register_sound('holy', 'holy.ogg')
register_sound('appear', 'appear.ogg')

BalatroAidenMod.add_calculate(function(self, context)
    if context.before and is_flush_hand(context) and not aiden_joker_exists() then
        add_flush_shop_boost()
    end
end)

local create_card_ref = create_card
function create_card(_type, area, legendary, _rarity, skip_materialize, soulable, forced_key, key_append)
    local forced_by_flush_boost = false

    if _type == 'Joker'
        and G
        and G.shop_jokers
        and area == G.shop_jokers
    then
        if forced_key == AIDEN_JOKER and aiden_joker_exists() then
            forced_key = nil
        elseif not forced_key
            and not legendary
            and not aiden_joker_exists()
            and roll_flush_shop_boost()
        then
            forced_key = AIDEN_JOKER
            forced_by_flush_boost = true
        end
    end

    local created_card = create_card_ref(_type, area, legendary, _rarity, skip_materialize, soulable, forced_key, key_append)

    -- Only reset the boost counter AND play the sound when the flush boost
    -- mechanic is what actually forced the Aiden Joker into the shop.
    -- Previously, reset_flush_shop_boost() was in its own block with only
    -- card_is_aiden_joker() as a guard, so natural pool appearances would
    -- silently consume the accumulated boost and could trigger the sound.
    if forced_by_flush_boost and card_is_aiden_joker(created_card) then
        reset_flush_shop_boost()

        if created_card.juice_up then
            created_card:juice_up(0.7, 0.7)
        end

        play_registered_sound(APPEAR_SOUND, 1, 0.8)
    end

    return created_card
end

SMODS.Atlas {
    key = 'aidenjoker_Jokers',
    path = 'aidenjoker_Jokers.png',
    px = 71,
    py = 95,
    prefix_config = { key = false }
}

SMODS.Atlas {
    key = 'aidenjoker_CustomEnhancements',
    path = 'aidenjoker_CustomEnhancements.png',
    px = 71,
    py = 95,
    prefix_config = { key = false }
}

SMODS.Enhancement {
    key = AUTISTIC_ENHANCEMENT,
    atlas = 'aidenjoker_CustomEnhancements',
    prefix_config = { key = false, atlas = false },
    pos = { x = 0, y = 0 },
    config = {
        extra = {
            x_mult = 2
        }
    },
    loc_txt = {
        name = 'Autistic Card',
        text = {
            '{X:mult,C:white}X#1#{} Mult',
            'when scored'
        }
    },
    loc_vars = function(self, info_queue, card)
        local x_mult = self.config.extra.x_mult

        if card and card.ability and card.ability.extra and card.ability.extra.x_mult then
            x_mult = card.ability.extra.x_mult
        end

        return {
            vars = { x_mult }
        }
    end,
    calculate = function(self, card, context)
        if context.cardarea == G.play and context.main_scoring then
            local x_mult = self.config.extra.x_mult
            if card.ability and card.ability.extra and card.ability.extra.x_mult then
                x_mult = card.ability.extra.x_mult
            end

            juice_aiden_jokers()

            return {
                xmult = x_mult,
                message = 'X' .. x_mult .. ' Mult',
                colour = G.C.MULT,
                sound = registered_sounds[OH_MY_GOD_SOUND] and OH_MY_GOD_SOUND or nil,
                remove_default_message = true
            }
        end
    end,
    in_pool = function(self, args)
        return false
    end
}

SMODS.Joker {
    key = AIDEN_JOKER,
    prefix_config = { key = false, atlas = false },
    loc_txt = {
        name = 'Regular Aiden',
        text = {
            'Scored cards have a',
            '{C:green}#1# in #2#{} chance to become',
            '{C:attention}Autistic Cards{}',
            '{C:attention}Royal Flush{}, {C:attention}Straight Flush{},',
            '{C:attention}Four of a Kind{}, and {C:attention}Full House{}',
            'always apply it'
        }
    },
    config = {
        extra = {
            odds = 6
        }
    },
    loc_vars = function(self, info_queue, card)
        info_queue[#info_queue + 1] = G.P_CENTERS[AUTISTIC_ENHANCEMENT]

        local odds = self.config.extra.odds
        if card and card.ability and card.ability.extra and card.ability.extra.odds then
            odds = card.ability.extra.odds
        end

        local numerator, denominator = SMODS.get_probability_vars(
            card or self,
            1,
            odds,
            'aidenjoker_autistic'
        )

        return {
            vars = { numerator, denominator }
        }
    end,
    atlas = 'aidenjoker_Jokers',
    rarity = 1,
    cost = 6,
    unlocked = true,
    discovered = true,
    blueprint_compat = false,
    eternal_compat = true,
    perishable_compat = true,
    pos = { x = 0, y = 0 },
    in_pool = function(self, args)
        return not aiden_joker_exists()
    end,
    calculate = function(self, card, context)
        if not (context.before and context.scoring_hand) then
            return
        end

        local rare_hand = is_rare_hand(context)
        local changed_cards = 0

        if rare_hand then
            play_registered_sound(HOLY_SOUND, 1, 0.8)
        end

        for i, scored_card in ipairs(context.scoring_hand) do
            local should_apply = rare_hand or SMODS.pseudorandom_probability(
                card,
                'aidenjoker_autistic_' .. i,
                1,
                card.ability.extra.odds,
                'aidenjoker_autistic'
            )

            if should_apply and apply_autistic_enhancement(scored_card, 0.05 * (i - 1)) then
                changed_cards = changed_cards + 1
            end
        end

        if changed_cards > 0 then
            return {
                message = rare_hand and 'Holy!' or 'Enhanced!',
                colour = rare_hand and G.C.GOLD or G.C.FILTER
            }
        end
    end
}
