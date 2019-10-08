import cs from 'classnames'
import _ from 'lodash'
import { action, observable } from 'mobx'
import { observer } from 'mobx-react'
import React, { Component } from 'react'

import { indent } from '../lib/util'

import Test from '../test/test'
import Collapsible from '../collapsible/collapsible'

const Suite = observer(({ model, config }) => {
  if (!model.shouldRender) return null

  return (
    <Collapsible
      header={<span className='runnable-title'>{model.title}</span>}
      headerClass='runnable-wrapper'
      headerStyle={{ paddingLeft: indent(model.level) }}
      contentClass='runnables-region'
      isOpen={true}
    >
      <ul className='runnables'>
        {_.map(model.children, (runnable) => <Runnable key={runnable.id} model={runnable} config={config} />)}
      </ul>
    </Collapsible>
  )
})

@observer
class Runnable extends Component {
  @observable isHovering = false

  render () {
    const { model, config } = this.props

    return (
      <li
        className={cs(`${model.type} runnable runnable-${model.state}`, {
          hover: this.isHovering,
        })}
        onMouseOver={this._hover(true)}
        onMouseOut={this._hover(false)}
      >
        {model.type === 'test' ? <Test model={model} config={config} /> : <Suite model={model} config={config} />}
      </li>
    )
  }

  _hover = (shouldHover) => action('runnable:hover', (e) => {
    e.stopPropagation()
    this.isHovering = shouldHover
  })
}

export { Suite }

export default Runnable
