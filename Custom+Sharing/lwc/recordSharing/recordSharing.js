import { LightningElement, track, api } from 'lwc';
import createRecord from '@salesforce/apex/SharingRecordHandler.createSharingRecord';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

export default class RecordSharing extends NavigationMixin(LightningElement) {
    @track userId;
    @track expiryDate;
    @api recordId;
    @track selectedAccessLevel = 'Read'; 
    @api objectApiName;

    accessOptions = [
        { label: 'Read', value: 'Read' },
        { label: 'Edit', value: 'Edit' }
    ];

    save() {
        const inputs = this.template.querySelectorAll('[data-name]');

        let userId, expiryDate;

        inputs.forEach(input => {
            if (input.dataset.name === 'userPicker') {
                userId = input.value; 
            } else if (input.dataset.name === 'expiryDate') {
                expiryDate = input.value; 
            }
        });

        console.log('Fetched User ID:', userId);
        console.log('Fetched Expiry Date:', expiryDate);

        const accessLevelInput = this.template.querySelector('[data-name="accessLevel"]');
        this.selectedAccessLevel = accessLevelInput ? accessLevelInput.value : 'Read';

        console.log('Fetched Access Level:', this.selectedAccessLevel);
        console.log('Fetched Record ID:', this.recordId);

        if (!userId || !expiryDate || !this.recordId || !this.selectedAccessLevel) {
            this.showToast('Error', 'Please fill in all required fields.', 'error');
            return;
        }

        createRecord({ recordIdString: this.recordId, expiryDate: expiryDate, userId: userId, selectedAccessLevel: this.selectedAccessLevel })
            .then(result => {
                if (result === 'Success') {
                    this.showToast('Success', 'Record Created Successfully!', 'success');
                    this.navigateToRecordDetail(); // Navigate to record detail page
                } else {
                    this.showToast('Error', result, 'error');
                }
            })
            .catch(error => {
                this.showToast('Error', 'Record is Already Shared', 'error');
                console.error('Error:', error);
            });
    }
    closeModal()
    {
        this.navigateToRecordDetail();
    }

    navigateToRecordDetail() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                actionName: 'view'
            }
        });
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}