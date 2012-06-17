$ ->
  amountLeft = 0
  barLeft = 100

  # Bootstrap plugins
  $('.dropdown-toggle').dropdown()
  $('.popover-toggle').popover()
  $('a[rel="tooltip"]').tooltip()

  # Navigation
  if $('nav').length
    $window     = $ window
    $nav        = $ 'nav'
    $done       = $ '#done'
    $whitespace = $ '#whitespace'
    offset      = $nav.length and $nav.offset().top

    # Set active menu item.
    $('body').scrollspy
      target: 'nav'
      offset: 50

    # Smooth scrolling.
    $nav.localScroll
      axis: 'y'
      duration: 500
      easing: 'easeInOutExpo'
      offset: -50
      hash: true

    # Fixed menu.
    processScroll = ->
      boolean = $window.scrollTop() >= offset
      height = $nav.outerHeight()
      if $done.is ':visible'
        height += $done.outerHeight()
      $nav.toggleClass 'nav-fixed', boolean
      $done.toggleClass 'done-fixed', boolean
      $whitespace.css(height: height).toggle boolean

    $window.on 'scroll', processScroll
    processScroll()

  # http://www.musicdsp.org/showone.php?id=238
  tanh = (x) ->
    if x < -3
      -1
    else if x > 3
      1
    else
      x * (27 + x * x) / (27 + 9 * x * x)

  # Converts a number to a currency.
  number_to_currency = (number) ->
    Mustache.render t('currency_format'),
      number: number.toString().replace(/\..*/, '').replace /(\d)(?=(\d\d\d)+(?!\d))/g, '$1' + t 'currency_delimiter'
      unit: t 'currency_unit'

  # Enables the identification form.
  enableForm = ->
    $('#identification').css 'opacity', 1
    $('#identification input,#identification textarea').prop 'disabled', false

  # Disables the identification form.
  disableForm = ->
    $('#identification').css 'opacity', 0.5
    $('#identification input,#identification textarea').prop 'disabled', true

  # Updates within-category balance.
  updateCategoryBalance = ($control) ->
    $table = $control.parents 'table'

    balance = 0
    $table.find('.slider').each ->
      $this = $ this
      balance -= ($this.slider('value') - parseFloat($this.attr('data-initial'))) * parseFloat($this.attr('data-value'))
    $table.find(':checkbox').each ->
      $this = $ this
      balance -= (+$this.prop('checked') - parseFloat($this.attr('data-initial'))) * parseFloat($this.attr('data-value'))

    $span = $ '#' + $table.attr('id') + '_link span'
    if $span.parents('.dropdown-menu').length
      $span.html(number_to_currency(balance)).css('color', if balance < 0 then '#f00' else '#000').toggle(balance != 0)

  # Updates within-group balance.
  updateBalance = ->
    balance = 0
    changed = false

    $.each ['revenue', 'expense'], (i, group) ->
      group_balance = 0
      amount = $ "##{group} .amount"
      bar = $ "##{group} .bar"

      # Calculate balance.
      $("""table[rel="#{group}"] .slider""").each ->
        $this = $ this
        difference = $this.slider('value') - parseFloat($this.attr('data-initial'))
        group_balance -= difference * parseFloat($this.attr('data-value'))
        if difference > 0
          changed = true
      $("""table[rel="#{group}"] :checkbox""").each ->
        $this = $ this
        difference = +$this.prop('checked') - parseFloat($this.attr('data-initial'))
        group_balance -= difference * parseFloat($this.attr('data-value'))
        if difference > 0
          changed = true

      balance += group_balance

      # Update group balance.
      currency = number_to_currency group_balance
      amount.html(currency).toggleClass 'negative', group_balance < 0

      # Move bar and balance.
      pixels = -Math.round(tanh(3 * group_balance / maximumDifference) * 100)
      width = Math.abs pixels

      # If at zero.
      if bar.width() == 0
        amount.animate left: amountLeft - pixels
        bar.css('background-color', if group_balance < 0 then '#f00' else '#000').animate
          left: Math.min(barLeft, barLeft - pixels)
          width: width
      # If going from negative to positive.
      else if group_balance > 0 and bar.position().left < barLeft
        amount.animate(left: amountLeft).animate(left: amountLeft - pixels)
        bar.animate
          left: barLeft,
          width: 0
        ,
          complete: ->
            $(this).css('background-color', '#000')
        .animate
          width: width
      # If going from positive to negative.
      else if group_balance < 0 and bar.position().left == barLeft
        amount.animate(left: amountLeft).animate(left: amountLeft - pixels)
        bar.animate
          width: 0
        ,
          complete: ->
            $(this).css('background-color', '#f00')
        .animate
          left: barLeft - pixels
          width: width
      # If not crossing zero.
      else
        amount.animate left: amountLeft - pixels
        bar.animate
          left: Math.min(barLeft, barLeft - pixels)
          width: width

    submittable = false
    message = $ '#message .inner'
    currency = number_to_currency balance

    # Update message.
    if balance < 0
      message.html t('deficit', number: currency)
    else if balance == 0
      if changed
        submittable = true
        message.html t('balanced')
      else
        message.html t('instructions')
    else
      if balance <= 50000 and changed
        submittable = true
        message.html t('nearly_balanced', number: currency)
      else
        message.html t('surplus', number: currency)

    if balance < 0
      message.css 'color', '#f00'
    else if balance == 0
      message.css 'color', '#666'
    else
      message.css 'color', '#000'


    # Enable or disable identification form.
    if submittable
      enableForm()
      $('#done').animate({height: 'show', opacity: 'show'}, 'slow')
    else
      disableForm()
      $('#done').animate({height: 'hide', opacity: 'hide'}, 'slow')

  highlight = ($control, current) ->
    $tr = $control.parents 'tr'
    initial = parseFloat $control.attr('data-initial')
    value = parseFloat $control.attr('data-value')

    if current == initial
      $tr.find('.impact').css 'visibility', 'hidden'
      if $tr.hasClass 'selected'
        $tr.removeClass 'selected'
        $tr.find('td.description').animate 'background-color': '#fff', 'slow'
        $tr.find('td.highlight').animate 'background-color': '#ff9', 'slow'
    else
      $tr.find('.value').html number_to_currency(Math.abs(current - initial) * value)
      $tr.find('.key').html if current - initial < 0 then t('savings') else t('costs')
      $tr.find('.impact').css 'visibility', 'visible'
      unless $tr.hasClass 'selected'
        $tr.addClass 'selected'
        $tr.find('td').animate 'background-color': '#add5f7', 'fast'

  slide = (event, ui) ->
    $this = $ this
    $this.find('.tip-content').html ui.value
    # Display tooltip unless value is both zero and the minimum value.
    $this.find('.tip').toggle ui.value != 0 || ui.value != parseFloat($this.attr('data-minimum'))
    highlight $this, ui.value

  change = (event, ui) ->
    $this = $ this
    # Perform same operations as if sliding.
    slide.call this, event, ui
    # Update form element.
    $this.find('input').val ui.value
    highlight $this, ui.value
    # Updating balance during slide is too expensive.
    updateCategoryBalance $this
    updateBalance()

  # Slider widget
  $('table .slider').each ->
    $this = $ this
    initial = parseFloat $this.attr('data-initial')
    minimum = parseFloat $this.attr('data-minimum')
    maximum = parseFloat $this.attr('data-maximum')

    $this.slider
      animate: true
      max: maximum
      min: minimum
      range: 'min'
      step: parseFloat $this.attr('data-step')
      value: initial
      create: (event, ui) ->
        $(this).find('a').append '<div class="tip"><div class="tip-content">' + initial + '</div><div class="tip-arrow"></div></div>'
        $(this).find('.tip').toggle initial != minimum
      slide: slide
      change: change

    # Place initial tick.
    if initial != maximum and initial != minimum
      $this.find('.tick.initial').width($this.find('a').position().left + 1).show()

  # Keyboard input can be confusing if slider is not visible.
  $('.ui-slider-handle').unbind 'keydown'

  # On/off widget
  $('table :checkbox').each ->
    $this = $ this
    options =
      resizeContainer: false
      onChange: (input, checked) ->
        highlight input, +checked
        updateCategoryBalance input
        updateBalance()
    if $this.is ':checked'
      options.checkedLabel = t 'no'
      options.uncheckedLabel = t 'yes'
      options.labelOffClass = 'iPhoneCheckLabelOff reverse'
      options.labelOnClass = 'iPhoneCheckLabelOn reverse'
    else
      options.resizeContainer = false
      options.checkedLabel = t 'yes'
      options.uncheckedLabel = t 'no'
    $this.iphoneStyle options

  $('.minimum').click ->
    $this = $ this
    $widget = $this.parents '.widget'
    $widget.find(':checkbox').prop('checked', false).trigger 'change'
    $slider = $widget.find('.slider')
    $slider.slider 'value', $slider.attr('data-minimum')

  $('.maximum').click ->
    $this = $ this
    $widget = $this.parents '.widget'
    $widget.find(':checkbox').prop('checked', true).trigger 'change'
    $slider = $widget.find '.slider'
    $slider.slider 'value', $slider.attr('data-maximum')

  # @todo smooth scroll submission link?
  # @todo
  #$('#survey').validationEngine()
  disableForm()