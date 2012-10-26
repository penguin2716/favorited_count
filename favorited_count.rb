# -*- coding: utf-8 -*-
Plugin.create :favorited_count do
  UserConfig[:global_favedcount] ||= 0
  @devils = {}

  def global_favedcount
    UserConfig[:global_favedcount]
  end

  def devils
    @devils
  end
  
  on_favorite do |service, user, message|
    if user != Service.primary.user
      if @devils[user.to_s] == nil
        @devils[user.to_s] = 0
      end
      @devils[user.to_s] += 1
      UserConfig[:global_favedcount] += 1
    end

    if UserConfig[:global_favedcount] % 1000 == 0 and UserConfig[:global_favedcount] > 0
      notice_devils(:system => false)
    end

  end

  def notice_devils(hash)
    top = @devils.sort_by{|key, value| -value}
    tweet = "現在のふぁぼカウント: #{UserConfig[:global_favedcount]}ふぁぼヾ(★⌒ー⌒★)ノ\n"
    if hash[:system]
      if top.size >= 10
        tweet += "mikutter起動後のふぁぼ魔Top10:\n"
        10.times { |n|
          tweet += "@#{top[n][0]} (#{top[n][1]}ふぁぼ)\n"
        }
      else
        tweet += "mikutter起動後のふぁぼ魔Top#{top.size}:\n"
        top.size.times { |n|
          tweet += "〄#{top[n][0]}(#{top[n][1]}ふぁぼ)\n"
        }
      end
      Plugin.call(:update, nil, [Message.new(:message => tweet, :system => true)])
    else
      if top.size >= 3
        tweet += "mikutter起動後のふぁぼ魔Top3は，〄#{top[0][0]}(#{top[0][1]}ふぁぼ)，〄#{top[1][0]}(#{top[1][1]}ふぁぼ)，〄#{top[2][0]}(#{top[2][1]}ふぁぼ)です！"
      elsif top.size > 0
        tweet += "mikutter起動後のふぁぼ魔Top3は"
        top.size.times { |n|
          tweet += "，〄#{top[n][0]}(#{top[n][1]}ふぁぼ)"
        }
        tweet += "です！"
      end
      Service.primary.post :message => tweet
    end
  end

  def min(rhs, lhs)
    if rhs < lhs
      rhs
    else
      lhs
    end
  end

  def hsv2rgb(hsv)
    h = (hsv[0] / 60.0).floor % 6
    f = hsv[0] / 60.0 - h
    p = hsv[2] * (1 - hsv[1])
    q = hsv[2] * (1 - f * hsv[1])
    t = hsv[2] * (1 - (1 - f) * hsv[1])
    case h
    when 0
      frgb = [ hsv[2], t, p]
    when 1
      frgb = [ q, hsv[2], p]
    when 2
      frgb = [ p, hsv[2], t]
    when 3
      frgb = [ p, q, hsv[2]]
    when 4
      frgb = [ t, p, hsv[2]]
    when 5
      frgb = [ hsv[2], p, q]
    end
    rgb = [ (frgb[0] * 0xffff).floor,
            (frgb[1] * 0xffff).floor,
            (frgb[2] * 0xffff).floor ]
  end

  filter_message_background_color do | mp, array |
    if @devils[mp.to_message.user.to_s]
      level = min(1.0, @devils[mp.to_message.user.to_s] / 100.0)
      array = hsv2rgb([100 * (1 - level), 0.3, 1.0])
    end
    [mp, array]
  end

end
