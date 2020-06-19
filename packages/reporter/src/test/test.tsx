import cs from 'classnames'
import { observer } from 'mobx-react'
import React, { Component } from 'react'
// @ts-ignore
import Tooltip from '@cypress/react-tooltip'

import events, { Events } from '../lib/events'
import appState, { AppState } from '../lib/app-state'
import { indent, onEnterOrSpace } from '../lib/util'
import runnablesStore, { RunnablesStore } from '../runnables/runnables-store'
import TestModel from './test-model'
import scroller, { Scroller } from '../lib/scroller'

import Attempts from '../attempts/attempts'

interface Props {
  events: Events
  appState: AppState
  runnablesStore: RunnablesStore
  scroller: Scroller
  model: TestModel
}

@observer
class Test extends Component<Props> {
  static defaultProps = {
    events,
    appState,
    runnablesStore,
    scroller,
  }

  componentDidMount () {
    this._scrollIntoView()
  }

  componentDidUpdate () {
    this._scrollIntoView()
    this.props.model.callbackAfterUpdate()
  }

  _scrollIntoView () {
    const { appState, model, scroller } = this.props
    const { isActive, shouldRender } = model

    if (appState.autoScrollingEnabled && appState.isRunning && shouldRender && isActive != null) {
      scroller.scrollIntoView(this.refs.container as HTMLElement)
    }
  }

  render () {
    const { model } = this.props

    if (!model.shouldRender) return null

    return (
      <div
        ref='container'
        className={cs('runnable-wrapper', { 'is-open': model.isOpen })}
        data-testid={model.id}
        onClick={model.toggleOpen}
        style={{ paddingLeft: indent(model.level) }}
      >
        <div className='runnable-content-region'>
          <i aria-hidden="true" className='runnable-state fas'></i>
          <span
            aria-expanded={!!model.isOpen}
            className='runnable-title'
            onKeyPress={onEnterOrSpace(model.toggleOpen)}
            role='button'
            tabIndex={0}
          >
            {model.title}
            <span className="visually-hidden">{model.state}</span>
          </span>
          <div className='runnable-controls'>
            <Tooltip placement='top' title='One or more commands failed' className='cy-tooltip'>
              <i className='fas fa-exclamation-triangle' />
            </Tooltip>
          </div>
        </div>
        {this._contents()}
      </div>
    )
  }

  _contents (this: Test) {
    // performance optimization - don't render contents if not open
    if (!this.props.model.isOpen) return null

    return (
      <div
        className='runnable-instruments collapsible-content'
        onClick={(e) => e.stopPropagation()}
      >
        <Attempts test={this.props.model} scrollIntoView={() => this._scrollIntoView()} />
      </div>
    )
  }

  _onErrorClick = (e:Event) => {
    e.stopPropagation()
    this.props.events.emit('show:error', this.props.model)
  }
}

export default Test
