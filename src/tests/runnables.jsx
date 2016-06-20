import _ from 'lodash'
import React from 'react'
import Runnable from './runnable-and-suite'

const NoTests = ({ spec }) => (
  <div className='no-tests'>
    <h4>
      <i className='fa fa-warning'></i>
      Sorry, there's something wrong with this file:
      <a href='https://on.cypress.io/theres-something-wrong-with-this-file' target='_blank'>
        <i className='fa fa-question-circle'></i>
      </a>
    </h4>
    <pre>{spec}</pre>
    <ul>
      <li>Have you written any tests?</li>
      <li>Are there typo’s or syntax errors?</li>
      <li>Check your Console for errors.</li>
      <li>Check your Network Tab for failed requests.</li>
    </ul>
  </div>
)

const RunnablesList = ({ tests }) => (
  <ul className='runnables'>
    {_.map(tests, (runnable) => <Runnable key={runnable.id} model={runnable} />)}
  </ul>
)

const Runnables = (props) => (
  <div className='tests'>
    <div className='tests-wrap'>
      {props.tests.length ? <RunnablesList {...props} /> : <NoTests {...props} />}
    </div>
  </div>
)

export default Runnables
