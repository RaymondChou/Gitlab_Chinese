window.Projects = ->
  $('.new_project, .edit_project').on 'ajax:before', ->
    $('.project_new_holder, .project_edit_holder').hide()
    $('.save-project-loader').show()

  $('form #project_default_branch').chosen()
  disableButtonIfEmptyField '#project_name', '.project-submit'

$ ->
  # Git clone panel switcher
  scope = $ '.project_clone_holder'
  if scope.length > 0
    $('a, button', scope).click ->
      $('a, button', scope).removeClass 'active'
      $(@).addClass 'active'
      $('#project_clone', scope).val $(@).data 'clone'

  # Ref switcher
  $('.project-refs-select').on 'change', ->
    $(@).parents('form').submit()

class @GraphNav
  @init: ->
    $('.graph svg').css 'position', 'relative'
    $('body').bind 'keyup', (e) ->
      $('.graph svg').animate(left: '+=400') if e.keyCode is 37 # left
      $('.graph svg').animate(left: '-=400') if e.keyCode is 39 # right
