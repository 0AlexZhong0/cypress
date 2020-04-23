import cs from 'classnames'
import _ from 'lodash'
import { observer } from 'mobx-react'
import React, { Component, Fragment } from 'react'

import appState from '../lib/app-state'
import events from '../lib/events'
import scroller from '../lib/scroller'

import Agents from '../agents/agents'
import Collapsible from '../collapsible/collapsible'
import Hooks from '../hooks/hooks'
import Routes from '../routes/routes'
import TestError from '../errors/test-error'
import TestModel from '../test/test-model'
import AttemptModel from './attempt-model'

const NoCommands = () => (
  <ul className='hooks-container'>
    <li className='no-commands'>
      No commands were issued in this test.
    </li>
  </ul>
)

const AttemptHeader = ({ index, isOpen }:{index: number, isOpen: boolean}) => (
  <span className='attempt-tag'>
    <span className={cs('open-close-indicator', { 'is-open': isOpen })}>
      <i className='fa fa-fw fa-angle-up' />
      <i className='fa fa-fw fa-angle-down' />
    </span>
    Attempt {index + 1}
    <i className='attempt-state runnable-state fa fa-fw' />
  </span>
)

@observer
class AttemptContent extends Component<{model: AttemptModel}> {
  render () {
    const { model } = this.props

    // performance optimization - don't render contents if not open
    if (!model.isOpen) return null

    return (
      <Fragment>
        <Agents model={model} />
        <Routes model={model} />
        <div ref='commands' className='runnable-commands-region'>
          {model.hasCommands ? <Hooks model={model} /> : <NoCommands />}
        </div>

        <div className='attempt-error-region'>
          <TestError events={events} model={model} isTestError={model.isLast} displayMessage={model.err.displayMessage}/>
        </div>
      </Fragment>
    )
  }
}

@observer
class Attempt extends Component<{model: AttemptModel}> {
  static defaultProps = {
    appState,
    scroller,
  }

  // componentDidMount () {
  //   this._scrollIntoView()
  //   this.props.model.callbackAfterUpdate()
  // }

  // componentDidUpdate () {
  //   this._scrollIntoView()
  //   this.props.model.callbackAfterUpdate()
  // }

  // _scrollIntoView () {
  //   const { appState, model, scroller } = this.props
  //   const { isActive } = model

  //   if (appState.autoScrollingEnabled && appState.isRunning && isActive != null) {
  //     scroller.scrollIntoView(this.refs.container)
  //   }
  // }

  render () {
    const { model } = this.props

    return (
      <li
        key={model.id}
        ref='container'
        className={cs('attempt-item', `attempt-state-${model.state}`, {
          'attempt-failed': model.state === 'failed',
        })}
      >
        <Collapsible
          header={<AttemptHeader index={model.id} isOpen={model.isOpen} />}
          headerClass='attempt-name'
          isOpen={model.isOpen}
          onToggle={model.toggleOpen}
        >
          <AttemptContent
            model={model}
          />
        </Collapsible>
      </li>
    )
  }
}

const Attempts = observer(({ test }: {test: TestModel}) => (
  <ul className={cs('attempts', {
    'has-multiple-attempts': test.hasMultipleAttempts,
  })}>
    {_.map(test.attempts, (attempt) => {
      return (
        <Attempt
          key={attempt.id}

          model={attempt}
        />
      )
    })}
  </ul>
))

export { Attempt, AttemptHeader, NoCommands }

export default Attempts
